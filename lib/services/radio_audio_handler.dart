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

    // 20260921 gjw A dropped stream surfaces here rather than as a thrown
    // error, because setUrl has already returned by the time the connection
    // fails. Report it as an error state so the notification and the car stop
    // claiming to be playing.

    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) stop();
    });
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
    _watchTrack(station);

    this.queue.add([
      for (final s in _queueStations) stationMediaItem(s, parentId),
    ]);
    mediaItem.add(stationMediaItem(station, parentId));

    try {
      await _player.setUrl(station.url);
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

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    // Stop polling the stream the moment playback stops, so a stopped app is
    // not quietly still fetching from a station in the background.

    await _trackSubscription?.cancel();
    _trackSubscription = null;

    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
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
    if (!needsIcyPolling) return;

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
