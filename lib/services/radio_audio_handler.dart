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

import 'package:flutter/foundation.dart';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/browse_tree.dart';

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
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    await super.stop();
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

    final station = _stations
        .where((s) => s.id == parts.stationId)
        .firstOrNull;
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
    final station = _stations
        .where((s) => s.id == parts.stationId)
        .firstOrNull;

    return station == null
        ? null
        : stationMediaItem(station, parts.parentId);
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
        androidCompactActionIndices: hasQueue
            ? const [0, 1, 2]
            : const [0],
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
