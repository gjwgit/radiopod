/// CaptionService — live, offline captions for the station on air.
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Tony Chen

library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:radio_pcm/radio_pcm.dart';
import 'package:rxdart/rxdart.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/captions/caption_engine.dart'
    if (dart.library.js_interop) 'package:radiopod/services/captions/caption_engine_web.dart';
import 'package:radiopod/services/captions/caption_text.dart';
import 'package:radiopod/services/captions/speech_model.dart';
import 'package:radiopod/services/player.dart';

/// What captions are doing, for the panel to say.

enum CaptionStatus {
  /// Switched off.
  off,

  /// The station on air needs a model that is not downloaded yet, and the
  /// listener has not yet agreed to fetch it.
  needsModel,

  /// Fetching the speech model, the first time captions are used.
  downloading,

  /// Loading the model, or connecting to the station.
  starting,

  /// Audio is arriving and being recognised.
  listening,

  /// Switched on, but nothing is playing.
  waiting,

  /// Something went wrong; [CaptionService.message] says what.
  failed,
}

/// Turns the station on air into text, on the device, as it is broadcast.
///
/// THE MODEL FOLLOWS THE STATION'S LANGUAGE — English, or Chinese and
/// English — as [speechModelFor] decides, and is swapped when a station in
/// the other language comes on.
///
/// NOTHING LEAVES THE DEVICE. Each model is downloaded once, and recognition
/// runs locally in its own isolate. The only network traffic is the model
/// download and a second connection to the station itself, open only while
/// captions are on — see StationReader in the radio_pcm plugin for why the
/// player's own connection cannot be used.
///
/// KEEPING IN STEP WITH THE PLAYER. A radio server typically sends a burst
/// of recent audio the moment anyone connects — ABC's Icecast stream sends
/// fifty seconds — and the player then plays that burst in real time. The
/// second connection receives the same burst, all at once. Recognising it as
/// fast as it arrived would put the captions nearly a minute ahead of what
/// is being heard. So samples are released to the recogniser against a
/// clock started when the first of them arrives, at the rate they would be
/// played; because both connections start from the same point in the
/// server's buffer, the captions then track the audio.

class CaptionService extends ChangeNotifier {
  CaptionService._();

  static final instance = CaptionService._();

  /// How far behind the first sample's arrival the player is assumed to be,
  /// allowing for it buffering before it starts. Recognition itself adds a
  /// fraction of a second, so the words land close to when they are spoken.

  static const _playerLead = Duration(milliseconds: 1500);

  /// The most audio held back for pacing. Beyond this the oldest is
  /// dropped, which costs a few words but never lets memory grow unbounded.

  static const _maxQueuedFrames = RadioPcm.sampleRate * 180;

  /// Lines kept in the transcript before the oldest are forgotten.

  static const _maxLines = 200;

  /// How often the lock screen is updated. Words arrive several times a
  /// second; the lock screen does not need to redraw that often.

  static const _publishInterval = Duration(milliseconds: 500);

  /// Whether the listener has switched captions on. Separate from the rest
  /// of the state so the CC button rebuilds only when it is toggled, not on
  /// every word.

  final active = ValueNotifier<bool>(false);

  CaptionStatus _status = CaptionStatus.off;
  double? _progress;
  String? _message;
  final _lines = <String>[];
  String _partial = '';

  /// The model the recogniser is running, or is being readied, for the
  /// station on air. Changes when the station changes language.

  SpeechModel? _model;

  /// Models the listener has agreed to download. A model is only ever
  /// fetched after they have been told its size and said yes.

  final _approved = <String>{};

  /// Bumped whenever the model changes, so a slow download or load that
  /// finishes after the listener has moved on is recognised as stale.

  int _generation = 0;

  Recogniser? _recogniser;
  StreamSubscription<RecognisedText>? _results;
  StreamSubscription<Object?>? _playerWatch;

  StreamSubscription<Float32List>? _pcm;
  Station? _capturing;
  DateTime? _connectedAt;
  int _retries = 0;
  Timer? _retryTimer;

  final _queue = ListQueue<Float32List>();
  int _queuedFrames = 0;
  int _releasedFrames = 0;
  DateTime? _clock;
  Timer? _pump;

  Timer? _publishTimer;
  DateTime _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Getters ───────────────────────────────────────────────────────────────

  /// False where there is no native decoder: everywhere but iOS and macOS.

  bool get supported => RadioPcm.isSupported;

  CaptionStatus get status => _status;

  /// The model in use, or wanted, for the station on air.

  SpeechModel? get model => _model;

  /// Download progress from 0 to 1, while [status] is downloading.

  double? get progress => _progress;

  String? get message => _message;

  /// Settled lines, oldest first.

  List<String> get lines => List.unmodifiable(_lines);

  /// The line still being heard, revised as more audio arrives.

  String get partial => _partial;

  /// The words being spoken right now: the line in progress, or the last
  /// one settled while nobody is speaking.

  String get currentLine =>
      _partial.isNotEmpty ? _partial : (_lines.isEmpty ? '' : _lines.last);

  Future<bool> isModelInstalled(SpeechModel model) =>
      SpeechModelStore.isInstalled(model);

  /// Remove a downloaded model. If captions are using it they are switched
  /// off first, since the files are about to disappear from under them.

  Future<void> deleteModel(SpeechModel model) async {
    if (_model?.id == model.id) await disable();
    _approved.remove(model.id);
    await SpeechModelStore.delete(model);
    notifyListeners();
  }

  // ── Switching on and off ──────────────────────────────────────────────────

  /// Switch captions on for the station on air.
  ///
  /// [approved] is the model the listener has just agreed to download, as
  /// toggleCaptions asks before any download. Without it, a model that is
  /// not yet here waits in [CaptionStatus.needsModel] for [downloadModel].

  Future<void> enable({SpeechModel? approved}) async {
    if (!supported || active.value) return;
    if (approved != null) _approved.add(approved.id);

    active.value = true;
    _lines.clear();
    _partial = '';
    _message = null;
    _watchPlayer();
    _sync();
  }

  /// Fetch the model the station on air needs, which the listener has just
  /// agreed to from the caption panel.

  void downloadModel() {
    final model = _model;
    if (!active.value || model == null) return;
    _approved.add(model.id);
    unawaited(_load(model));
  }

  Future<void> disable() async {
    if (!active.value) return;
    active.value = false;
    _generation++;

    await _stopCapture();
    await _playerWatch?.cancel();
    _playerWatch = null;
    await _dropRecogniser();
    _model = null;

    _publishTimer?.cancel();
    _publishTimer = null;
    Player.handler.setCaption(null);

    _lines.clear();
    _partial = '';
    _message = null;
    _set(CaptionStatus.off);
  }

  /// Let the recogniser go. It holds its model in memory, some tens of
  /// megabytes, so it goes as soon as it is not wanted rather than waiting
  /// to be reused.

  Future<void> _dropRecogniser() async {
    await _results?.cancel();
    _results = null;
    _recogniser?.close();
    _recogniser = null;
  }

  void _onDownloadProgress(double p) {
    // Whole percent steps only: the download arrives in thousands of chunks
    // and each notification rebuilds the panel.

    if (_progress != null && (p * 100).floor() == (_progress! * 100).floor()) {
      return;
    }
    _progress = p;
    notifyListeners();
  }

  // ── Choosing the model ────────────────────────────────────────────────────

  /// Make [model] the one in use: close whatever was running, and download
  /// and start this one, or wait for the listener's say-so to download it.

  Future<void> _useModel(SpeechModel model) async {
    _generation++;
    _model = model;

    // Everything that belongs to the old model goes BEFORE the first await.
    // Player events keep arriving meanwhile — a station switch brings a
    // stop and a play of its own — and each runs [_sync], which must not
    // find the old recogniser still in place and carry on with it, nor the
    // last station's words still showing under the new one.

    final results = _results;
    final recogniser = _recogniser;
    _results = null;
    _recogniser = null;
    _lines.clear();
    _partial = '';
    Player.handler.setCaption(null);
    notifyListeners();

    await _stopCapture();
    await results?.cancel();
    recogniser?.close();
    await _load(model);
  }

  Future<void> _load(SpeechModel model) async {
    final generation = _generation;
    bool current() =>
        active.value && generation == _generation && _model?.id == model.id;

    try {
      if (!await SpeechModelStore.isInstalled(model)) {
        if (!current()) return;
        if (!_approved.contains(model.id)) {
          _set(CaptionStatus.needsModel);

          return;
        }

        _set(CaptionStatus.downloading, progress: 0);
        await SpeechModelStore.download(
          model,
          onProgress: (p) {
            if (current()) _onDownloadProgress(p);
          },
          cancelled: () => !current(),
        );
        if (!current()) return;
      }
    } catch (e) {
      if (current()) {
        _fail(
          'The ${model.language} speech model could not be downloaded. Check '
          'the connection and try again. ($e)',
        );
      }

      return;
    }

    try {
      if (!current()) return;
      _set(CaptionStatus.starting);
      final recogniser = await Recogniser.start(model);
      if (!current()) {
        recogniser.close();

        return;
      }
      _recogniser = recogniser;
      _results = recogniser.results.listen(_onResult);
      _sync();
    } catch (e) {
      if (current()) {
        _fail('The ${model.language} speech model could not be started. ($e)');
      }
    }
  }

  // ── Following the player ──────────────────────────────────────────────────

  /// Re-check what to capture whenever the station, or whether it is
  /// playing, changes.

  void _watchPlayer() {
    _playerWatch = Rx.combineLatest2(
      Player.handler.currentStation,
      Player.handler.playbackState.map((s) => s.playing).distinct(),
      (Station? station, bool playing) =>
          (station?.id, station?.url, station?.language, playing),
    ).distinct().listen((_) => _sync());
  }

  void _sync() {
    if (!active.value) return;

    final station = Player.handler.currentStation.value;
    final playing = Player.handler.playbackState.value.playing;

    // A station in a language captions cannot do switches them off. The CC
    // button is greyed out for it too, so there is no state in which they
    // are on but can never show anything.

    final wanted = speechModelFor(station);
    if (station != null && wanted == null) {
      unawaited(disable());

      return;
    }

    if (wanted != null && wanted.id != _model?.id) {
      unawaited(_useModel(wanted));

      return;
    }

    // Still downloading, loading, or waiting for leave to download.

    if (_recogniser == null) return;

    if (station == null || !playing) {
      unawaited(_stopCapture());
      Player.handler.setCaption(null);
      _set(CaptionStatus.waiting);

      return;
    }

    final same = _capturing?.id == station.id && _capturing?.url == station.url;
    if (same && (_pcm != null || _retryTimer != null)) return;

    // A different station is a different conversation. The same one,
    // resumed, keeps what was said before the pause.

    if (_capturing?.id != station.id) {
      _lines.clear();
      _partial = '';
    }
    unawaited(_stopCapture());
    _retries = 0;
    _startCapture(station);
  }

  void _startCapture(Station station) {
    _capturing = station;
    _connectedAt = DateTime.now();
    _partial = '';
    _recogniser?.reset();
    _resetClock();
    _set(CaptionStatus.starting);

    _pcm = RadioPcm.open(station.url).listen(
      _enqueue,
      onError: (Object e) => _onCaptureError(station, e),
      onDone: () => _onCaptureEnded(station),
    );
    _pump = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _release(),
    );
  }

  Future<void> _stopCapture() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _pump?.cancel();
    _pump = null;
    _resetClock();

    final pcm = _pcm;
    _pcm = null;
    await pcm?.cancel();
  }

  bool _stillWanted(Station station) =>
      active.value &&
      Player.handler.currentStation.value?.id == station.id &&
      Player.handler.playbackState.value.playing;

  void _onCaptureError(Station station, Object e) {
    if (!_stillWanted(station)) return;

    // A dropped connection is worth another try; anything else — a format
    // that cannot be decoded, an encrypted stream — will fail the same way
    // again, so say so and stop.

    if (e is PlatformException && e.code == 'network') {
      _onCaptureEnded(station);

      return;
    }

    final message = e is PlatformException ? e.message : '$e';
    _fail(message ?? 'Captions stopped unexpectedly.');
  }

  /// The station's stream ended on our connection. The player may well have
  /// reconnected to it already — ABC does this after every bulletin — so do
  /// the same, a few times, backing off.

  void _onCaptureEnded(Station station) {
    if (!_stillWanted(station)) return;

    // Cancelled rather than just forgotten: after an error the channel
    // stream is still open, and leaving it would keep a listener alive
    // beside the one the retry opens.

    unawaited(_pcm?.cancel());
    _pcm = null;
    _pump?.cancel();
    _pump = null;

    final lasted = DateTime.now().difference(_connectedAt ?? DateTime.now());
    if (lasted > const Duration(minutes: 1)) _retries = 0;

    if (_retries >= 5) {
      _fail('The station keeps dropping the connection used for captions.');

      return;
    }

    _retries++;
    _set(CaptionStatus.starting);
    _retryTimer = Timer(Duration(seconds: 2 * _retries), () {
      _retryTimer = null;
      if (_stillWanted(station)) _startCapture(station);
    });
  }

  void _fail(String message) {
    unawaited(_stopCapture());
    Player.handler.setCaption(null);
    _message = message;
    _set(CaptionStatus.failed);
  }

  // ── Pacing ────────────────────────────────────────────────────────────────

  void _resetClock() {
    _queue.clear();
    _queuedFrames = 0;
    _releasedFrames = 0;
    _clock = null;
  }

  void _enqueue(Float32List samples) {
    if (_status != CaptionStatus.listening) _set(CaptionStatus.listening);

    _clock ??= DateTime.now().add(_playerLead);
    _queue.add(samples);
    _queuedFrames += samples.length;

    // Dropped audio still counts as released, so the clock stays in step
    // with the player even when words are lost.

    while (_queuedFrames > _maxQueuedFrames && _queue.isNotEmpty) {
      final old = _queue.removeFirst();
      _queuedFrames -= old.length;
      _releasedFrames += old.length;
    }
  }

  void _release() {
    final clock = _clock;
    final recogniser = _recogniser;
    if (clock == null || recogniser == null) return;

    final due =
        DateTime.now().difference(clock).inMicroseconds *
        RadioPcm.sampleRate ~/
        Duration.microsecondsPerSecond;

    while (_queue.isNotEmpty && _releasedFrames < due) {
      final samples = _queue.removeFirst();
      _queuedFrames -= samples.length;
      _releasedFrames += samples.length;
      recogniser.accept(samples);
    }
  }

  // ── Results ───────────────────────────────────────────────────────────────

  void _onResult(RecognisedText result) {
    if (!active.value || _pcm == null) return;

    final text = tidyCaption(result.text);
    if (result.isFinal) {
      if (text.isNotEmpty) {
        _lines.add(text);
        if (_lines.length > _maxLines) _lines.removeAt(0);
      }
      _partial = '';
    } else {
      _partial = text;
    }

    notifyListeners();
    _schedulePublish();
  }

  /// Put the current words on the lock screen, at most every
  /// [_publishInterval], always finishing with the latest.

  void _schedulePublish() {
    if (_publishTimer != null) return;

    final wait = _lastPublish.add(_publishInterval).difference(DateTime.now());
    _publishTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _publishTimer = null;
      _lastPublish = DateTime.now();
      if (!active.value || _pcm == null) return;

      // The end of the last line and the words since, run together, so the
      // lock screen scrolls on continuously like lyrics rather than
      // dropping to a two-word fragment each time a line settles.

      final line = joinCaptions(_lines.isEmpty ? '' : _lines.last, _partial);
      Player.handler.setCaption(line.isEmpty ? null : captionTail(line));
    });
  }

  void _set(CaptionStatus status, {double? progress}) {
    _status = status;
    _progress = progress;
    if (status != CaptionStatus.failed) _message = null;
    notifyListeners();
  }
}
