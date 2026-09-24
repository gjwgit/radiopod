/// RadioAudioHandler — background playback and the Android Auto media session.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/browse_tree.dart';
import 'package:radiopod/services/icy_reader.dart';
import 'package:radiopod/services/stream_end_policy.dart';
import 'package:radiopod/utils/platform_io.dart'
    if (dart.library.js_interop) 'package:radiopod/utils/platform_web.dart';

/// The single audio handler, shared by the Flutter UI, the system
/// notification, the lock screen, headset buttons and Android Auto.
///
/// Everything that plays audio goes through here. The UI never touches the
/// [AudioPlayer] directly, so the state the car shows and the state the app
/// shows can never disagree.
///
/// Live radio has no duration and no meaningful position, so this handler
/// deliberately does NOT mix in SeekHandler and does not offer fast-forward
/// or rewind. Stations are switched with Next and Previous instead, moving
/// through whichever playlist the station was started from.

class RadioAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  /// The library, pushed in by AppProvider whenever it changes.

  List<Station> _stations = [];
  List<Playlist> _playlists = [];

  /// The stations Next and Previous move through, and where we are in them.
  ///
  /// Set from the folder the current station was started from, so the queue
  /// matches what the driver was browsing.

  List<Station> _queueStations = [];
  int _queueIndex = -1;

  /// The browse folder the current queue came from, so a skip keeps reporting
  /// the same folder in its media ids rather than silently falling back to
  /// All Stations.

  String _queueParentId = browseAllStationsId;

  /// The station on air, and the track it last announced.
  ///
  /// Both are needed to rebuild the published media item when ICY metadata
  /// arrives: the station supplies the name and logo, the track the subtitle.

  /// When the current station started, and how many stations in a row have
  /// ended too quickly to have really played. Together these stop
  /// auto-advance from becoming a loop over a queue of dead stations.

  DateTime? _startedAt;
  int _failedAdvances = 0;

  /// Runs while we wait to see whether a stream that ended comes back by
  /// itself. Non-null means an advance is pending and can still be called
  /// off. See [_onStreamEnded].

  Timer? _endTimer;

  /// True once [stop] has released the platform player, so [play] knows it
  /// has to open the station again rather than try to resume a source that
  /// is no longer loaded.

  bool _stopped = false;

  /// How long to wait for a station to open before calling it a failure.
  ///
  /// Generous, because a distant station on a slow connection is not an
  /// error. It exists only so a load that will NEVER finish cannot leave the
  /// row spinning for ever — see the use in [playStation].

  static const _openTimeout = Duration(seconds: 30);

  Station? _currentStation;
  String? _currentTrack;

  /// The desktop track reader for the current station, cancelled whenever
  /// playback moves on so only one stream is ever being polled.

  StreamSubscription<String?>? _trackSubscription;

  /// The folder ids a client has subscribed to, so a library change can tell
  /// each one to re-read its children.

  final _childSubjects = <String, BehaviorSubject<Map<String, dynamic>>>{};

  RadioAudioHandler() {
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        debugPrint('[RadioAudioHandler] playback event error: $e');
      },
    );

    // 20260921 gjw playbackEventStream does not fire for every play/pause
    // transition — the processing state is unchanged when an already-buffered
    // stream is simply resumed — so the notification and the car would keep
    // showing the old transport state. Watching playingStream as well closes
    // that gap; _broadcastState reads _player.playing either way, so the
    // duplicate broadcast is harmless.

    _player.playingStream.listen((_) => _broadcastState(null));

    // 20260921 gjw Shoutcast and Icecast streams announce the song on air in
    // band, as ICY metadata, and just_audio surfaces it here. Republishing
    // the media item on each announcement is what puts the track under the
    // station name in the app, in the notification, and on the car's
    // now-playing screen.

    _player.icyMetadataStream.listen(_broadcastTrack);

    // 20260922 gjw Most internet radio is an endless stream, but not all of
    // it: NPR and other bulletin feeds genuinely END when the bulletin is
    // over, and a dropped connection arrives here the same way, because
    // setUrl has long since returned by the time it fails. Either way,
    // sitting on a finished stream is the wrong thing — move to the next
    // station, as Transistor does.

    // 20260923 gjw `s.playing` is part of the test, not decoration. When a
    // live source genuinely runs out just_audio leaves playing TRUE and only
    // moves the processing state to completed — see [_resumed]. A completed
    // arriving with playing FALSE is therefore not a station ending; it is
    // the player being torn down or swapped, and acting on it auto-stopped
    // the station a few seconds after every manual Stop then Play.

    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && s.playing) {
        _onStreamEnded();
      } else if (_resumed) {
        // The stream picked itself back up. Call off any pending advance.

        _cancelPendingAdvance();
      }
    });
  }

  /// True when the player is actually producing audio again.
  ///
  /// Note that `playing` alone is NOT enough: just_audio leaves `playing`
  /// true when a source runs out, and only moves `processingState` to
  /// completed. Both have to be checked.

  bool get _resumed =>
      _player.playing &&
      _player.processingState != ProcessingState.completed &&
      _player.processingState != ProcessingState.idle;

  void _cancelPendingAdvance() {
    _endTimer?.cancel();
    _endTimer = null;
  }

  /// A stream has run out. Reconnect, move on, or stop.
  ///
  /// A STATION THAT WAS PLAYING PROPERLY IS RECONNECTED, NOT ABANDONED. ABC
  /// News Radio closes the connection at the end of each bulletin and is
  /// still on air immediately afterwards; the player does NOT pick it up by
  /// itself, so RadioPod has to open it again. Waiting instead of
  /// reconnecting, as an earlier version did, just produced a long silence
  /// and then the wrong station.
  ///
  /// [decideStreamEnd] holds the rule that separates that case from a
  /// station that has genuinely finished.

  void _onStreamEnded() {
    if (_currentStation == null) return;

    // A station the user stopped has not "ended", so it must not reconnect,
    // advance to the next station, or count towards the failure tally.

    if (_stopped) return;

    // A stream can report completed more than once. The first report starts
    // the clock; later ones must not restart it.

    if (_endTimer != null) return;

    final played = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);

    // Read the flag from the library rather than from _currentStation, which
    // is a snapshot taken when playback started. Otherwise turning the
    // setting on for the station playing right now would not take effect
    // until it was started again.

    final station = _stations
        .where((s) => s.id == _currentStation!.id)
        .firstOrNull;
    final reconnectOnEnd =
        station?.reconnectOnEnd ?? _currentStation!.reconnectOnEnd;

    final decision = decideStreamEnd(
      queueLength: _queueStations.length,
      failedAdvances: _failedAdvances,
      played: played,
      reconnectOnEnd: reconnectOnEnd,
    );
    _failedAdvances = decision.failedAdvances;

    debugPrint(
      '[RadioAudioHandler] ${_currentStation?.name} ended after '
      '${played.inSeconds}s (reconnectOnEnd: $reconnectOnEnd) '
      '-> ${decision.action.name}',
    );

    // A reconnect happens AT ONCE. This is a station that was playing
    // happily a moment ago, so every extra second is an audible hole where
    // there used to be well under one.

    if (decision.action == StreamEndAction.reconnect) {
      unawaited(_reconnectCurrent());

      return;
    }

    // The other two paths do pause first, in case the player picks the
    // stream back up by itself and saves us the trouble. The decision is
    // carried through rather than recomputed, so time spent waiting can
    // never be mistaken for time spent playing.

    _endTimer = Timer(resumeGrace, () => _carryOut(decision.action));
  }

  /// Open the current station again after a break in transmission.
  ///
  /// [_startedAt] is reset BEFORE the attempt, so that a connection which
  /// also ends immediately scores as a failure and the queue moves on,
  /// rather than inheriting the long healthy run that earned the reconnect.
  /// That is what stops a station which ends over and over from being
  /// reconnected for ever.

  Future<void> _reconnectCurrent() async {
    final station = _currentStation;
    if (station == null) return;

    _startedAt = DateTime.now();
    try {
      await _player.setUrl(station.url);
      await _player.play();
    } catch (e) {
      debugPrint('[RadioAudioHandler] reconnect to ${station.name} failed: $e');

      // The station really has gone. Decide again, now scoring as a failure.

      _onStreamEnded();
    }
  }

  /// Carry out an advance or a stop, unless the stream came back meanwhile.

  void _carryOut(StreamEndAction action) {
    _cancelPendingAdvance();
    if (_currentStation == null || _resumed) return;

    if (action == StreamEndAction.stop) {
      stop();

      return;
    }

    // Nothing awaits this, and playStation rethrows when a stream will not
    // open at all. Such a station never reaches `completed`, so without
    // catching it here the chain would stop dead on the first bad URL — and
    // the throw would surface as an unhandled async error.
    //
    // Straight back to _carryOut rather than through _onStreamEnded: a
    // stream that refused to open has nothing to come back from, so waiting
    // out another grace period would only add silence between dead stations.

    unawaited(
      skipToNext().catchError((Object e) {
        debugPrint('[RadioAudioHandler] auto-advance could not start: $e');
        _carryOut(StreamEndAction.advance);
      }),
    );
  }

  // ── Library ───────────────────────────────────────────────────────────────

  /// Replace the library the browse tree is built from.
  ///
  /// Called on every load from the Pod and on every edit, so a station added
  /// on the phone shows up in the car without a restart.

  void setLibrary(List<Station> stations, List<Playlist> playlists) {
    _stations = stations;
    _playlists = playlists;

    // Nudge every subscribed folder. The value is the subscription options
    // map, which we do not use; it is the notification itself that matters.

    for (final entry in _childSubjects.entries) {
      entry.value.add(<String, dynamic>{});
    }
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Start [station], with Next and Previous moving through [queue].
  ///
  /// [queue] is the list the station was picked from — a playlist, a filtered
  /// view, or just the one station. Passing it explicitly keeps the skip
  /// behaviour the same whether playback started in the app or in the car.

  Future<void> playStation(
    Station station, {
    List<Station>? queue,
    String parentId = browseAllStationsId,
  }) async {
    _queueStations = (queue == null || queue.isEmpty) ? [station] : queue;
    _queueParentId = parentId;
    _queueIndex = _queueStations.indexWhere((s) => s.id == station.id);
    if (_queueIndex < 0) {
      _queueStations = [station];
      _queueIndex = 0;
    }

    // Forget the previous station's track before the new stream announces
    // its own, so a switch never leaves the old song showing under the new
    // station's name.

    _currentStation = station;
    _currentTrack = null;
    _startedAt = DateTime.now();
    _stopped = false;

    // Any advance still pending for the station we are leaving belongs to
    // that station, not this one.

    _cancelPendingAdvance();
    _watchTrack(station);

    this.queue.add([
      for (final s in _queueStations) stationMediaItem(s, parentId),
    ]);
    mediaItem.add(stationMediaItem(station, parentId));

    try {
      // Silence whatever is on BEFORE opening the next station.
      //
      // setUrl is supposed to replace the media by itself, and on native
      // platforms it does. On the web just_audio drives a single shared
      // <audio> element, and assigning a new src to one that still holds a
      // live stream is not a reliable reset: the old station carried on
      // while the row already showed the new one as playing. Pausing first
      // was not enough either — a paused element still holds its stream —
      // so this uses the same full reset that Stop does.

      await _silence();

      // A live stream has no duration, and just_audio's web backend waits on
      // a durationchange event to decide a load has finished. That event can
      // simply never arrive, which left the row spinning on "Connecting…"
      // with no way back. Failing is better than hanging: the row can then
      // show the error and be tapped again.

      await _player.setUrl(station.url).timeout(_openTimeout);
      await _player.play();
    } catch (e) {
      debugPrint('[RadioAudioHandler] cannot play ${station.url}: $e');
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          playing: false,
        ),
      );

      rethrow;
    }
  }

  /// Start playing again after a stop.
  ///
  /// RE-OPENS THE STATION RATHER THAN RESUMING. just_audio's `stop()` tears
  /// the platform player down, and its `play()` then brings a new one up and
  /// reloads the source with the position the old one had reached:
  ///
  ///     initialSeekValues = (index: currentIndex, position: position)
  ///
  /// For a file that restores where you were. For LIVE RADIO there is
  /// nothing to seek to, and libmpv refuses outright — "Cannot seek in this
  /// stream" — leaving a player that reports itself as playing while no
  /// audio arrives. Opening the URL afresh starts at the live edge, which is
  /// the only thing a resumed radio station could sensibly mean anyway.

  @override
  Future<void> play() async {
    final station = _currentStation;
    if (_stopped && station != null) {
      await playStation(
        station,
        queue: _queueStations,
        parentId: _queueParentId,
      );

      return;
    }

    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  /// Silence the player the way this platform needs.
  ///
  /// Shared by [stop] and by [playStation], because switching station has
  /// exactly the same requirement as stopping: whatever was on must be gone
  /// BEFORE the next URL is opened. Having the two do different things is
  /// what let the previous station keep playing under the new one's name.
  ///
  /// See [stopByPause] for why libmpv pauses while everything else stops.

  Future<void> _silence() => stopByPause ? _player.pause() : _player.stop();

  @override
  Future<void> stop() async {
    // 20260923 gjw ON LIBMPV, STOP PAUSES RATHER THAN TEARING THE PLAYER
    // DOWN. Elsewhere it really stops. See [stopByPause].
    //
    // just_audio's own stop() disposes the platform player, and bringing one
    // back up reloads the source at the position the old one reached — which
    // a live stream cannot seek to, so playback came back silent. Worse, the
    // teardown itself emits a completed state that the stream-end listener
    // above read as "the station finished", stopping it again seconds after
    // every Stop then Play. On Linux the libmpv dispose is also slow enough
    // to leave the button looking dead, and is a likely source of the crash
    // on quit.
    //
    // 20260924 gjw That was first applied to every platform, which was too
    // broad. The seek complaint no longer applies anywhere, because [play]
    // re-opens the station rather than resuming it, and the completed state
    // is caught by the guards in the listener and in _onStreamEnded. What
    // remains is a libmpv concession.
    //
    // On the web pausing was actively wrong. The browser gives just_audio one
    // shared audio element, so a paused element still holds the previous
    // stream: the old station stayed audible, and loading the next one into
    // it waited on a durationchange event that a live stream never fires,
    // leaving the row on "Connecting…" indefinitely.
    //
    // A real stop also drops the connection, which is what a listener means
    // by Stop. Pausing keeps it open until the next play.

    await _silence();
    _stopped = true;
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );

    // Stop polling the stream the moment playback stops, so a stopped app is
    // not quietly still fetching from a station in the background.

    await _trackSubscription?.cancel();
    _trackSubscription = null;

    // A stop ends the current run, so the next thing the user starts gets a
    // full set of auto-advance attempts rather than inheriting the tally
    // from a queue of stations that would not play.

    _failedAdvances = 0;
    _startedAt = null;

    // A deliberate stop must not be followed moments later by an advance
    // that was already in flight.

    _cancelPendingAdvance();

    await super.stop();
  }

  /// Republish the current media item with the track [icy] announces.
  ///
  /// NOT AVAILABLE ON EVERY PLATFORM. just_audio_media_kit reports
  /// `icyMetadata: null` unconditionally, so on Linux and Windows desktop
  /// this never fires and the subtitle stays on the station's own details.
  /// Plenty of streams on the supported platforms send nothing either, or
  /// send their own station name rather than a song, so the UI must always
  /// read as correct with no track at all.

  void _broadcastTrack(IcyMetadata? icy) => _setTrack(icy?.info?.title);

  /// Publish [title] as the song on air, ignoring a repeat of what is already
  /// showing so the media session is not churned on every poll.

  void _setTrack(String? title) {
    final station = _currentStation;
    if (station == null) return;

    final track = _cleanTrack(title);
    if (track == _currentTrack) return;

    _currentTrack = track;
    mediaItem.add(stationMediaItem(station, _queueParentId, track: track));
  }

  /// Start (or restart) reading the song on air for [station].
  ///
  /// Only runs where the player itself reports nothing — GNU/Linux and
  /// Windows, where just_audio_media_kit hardcodes `icyMetadata: null`.
  /// Everywhere else [_broadcastTrack] is already being fed by the player on
  /// the connection it has open, and polling would be pure waste.

  void _watchTrack(Station station) {
    _trackSubscription?.cancel();
    _trackSubscription = null;
    if (!needsIcyPolling || !icyPollingEnabled) return;

    _trackSubscription = IcyReader.watch(station.url).listen(
      (title) {
        // Ignore a late result for a station the user has already left.

        if (_currentStation?.id == station.id) _setTrack(title);
      },
      onError: (Object e) {
        debugPrint('[RadioAudioHandler] track reader error: $e');
      },
    );
  }

  /// Tidy an ICY title, mapping anything useless to null.
  ///
  /// Stations pad titles with whitespace, and a good number send the station
  /// name or a placeholder when nothing is playing. Echoing the station name
  /// back under itself looks broken, so that case falls through to the
  /// station details instead.

  String? _cleanTrack(String? title) {
    final t = title?.trim();
    if (t == null || t.isEmpty) return null;
    if (t.toLowerCase() == _currentStation?.name.trim().toLowerCase()) {
      return null;
    }

    return t;
  }

  @override
  Future<void> skipToNext() => _skipBy(1);

  @override
  Future<void> skipToPrevious() => _skipBy(-1);

  /// Move [delta] stations through the current queue, wrapping at the ends.
  ///
  /// Wrapping matters in the car: a driver pressing Next on the last station
  /// should land back at the first rather than have nothing happen.

  Future<void> _skipBy(int delta) async {
    if (_queueStations.length < 2 || _queueIndex < 0) return;

    final n = _queueStations.length;
    final next = (_queueIndex + delta + n) % n;
    await playStation(
      _queueStations[next],
      queue: _queueStations,
      parentId: _queueParentId,
    );
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final parts = splitStationMediaId(mediaId);
    if (parts == null) return;

    final station = _stations.where((s) => s.id == parts.stationId).firstOrNull;
    if (station == null) return;

    // Rebuild the folder the driver was browsing so Next and Previous stay
    // inside it.

    final siblings = browseChildren(parts.parentId, _stations, _playlists)
        .map((m) => m.extras?['stationId'] as String?)
        .whereType<String>()
        .map((id) => _stations.where((s) => s.id == id).firstOrNull)
        .whereType<Station>()
        .toList();

    await playStation(station, queue: siblings, parentId: parts.parentId);
  }

  // ── Browsing (Android Auto) ───────────────────────────────────────────────

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async => browseChildren(parentMediaId, _stations, _playlists);

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) =>
      _childSubjects
          .putIfAbsent(
            parentMediaId,
            () => BehaviorSubject<Map<String, dynamic>>.seeded(
              <String, dynamic>{},
            ),
          )
          .stream;

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final parts = splitStationMediaId(mediaId);
    if (parts == null) return null;
    final station = _stations.where((s) => s.id == parts.stationId).firstOrNull;

    return station == null ? null : stationMediaItem(station, parts.parentId);
  }

  // ── State broadcast ───────────────────────────────────────────────────────

  /// Publish just_audio's state as a media session state.
  ///
  /// Stop rather than Pause is offered while playing: pausing a live stream
  /// only leaves a stalled buffer to resume from, so stopping and restarting
  /// is the honest control. Position and buffered position are left at zero
  /// because a live stream has no timeline to show.
  ///
  /// The event is not read — everything comes from the player itself — so it
  /// is nullable, letting playingStream call this too.

  void _broadcastState(PlaybackEvent? event) {
    final playing = _player.playing;
    final hasQueue = _queueStations.length > 1;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (hasQueue) MediaControl.skipToPrevious,
          if (playing) MediaControl.stop else MediaControl.play,
          if (hasQueue) MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.play, MediaAction.stop},
        androidCompactActionIndices: hasQueue ? const [0, 1, 2] : const [0],
        processingState: _processingState[_player.processingState]!,
        playing: playing,
        queueIndex: _queueIndex < 0 ? null : _queueIndex,
      ),
    );
  }

  static const _processingState = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };
}
