/// RadioAudioHandler's podcast half — playing casts with a timeline.
///
// Time-stamp: <Sunday 2026-10-18 21:31:25 +1100 Graham Williams>
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
/// Authors: Graham Williams

part of 'radio_audio_handler.dart';

/// How many casts in a row may fail to open before a podcast stops trying.
/// A feed whose files have all moved must not be walked end to end.

const _castFailureLimit = 3;

/// Cast playback for [RadioAudioHandler].
///
/// 20261016 gjw The listener's place is written to [CastStore] — on pause,
/// stop and switch, every [castSaveEvery] while playing, and at the end —
/// because this is the only code running when the car plays a podcast with
/// the phone in a pocket. AppProvider, when the app is open, carries the
/// store to the Pod.

extension CastHandling on RadioAudioHandler {
  /// Listen for what casts need from outside the player.

  void _watchCasts() {
    // A feed may not state a cast's length; the player finds it out.

    _player.durationStream.listen(_learnCastDuration);

    // A cast heard to the end, or switched off on the phone, changes how
    // many a podcast has to play; the car's rows should say so. Progress
    // alone changes no count, so most of these are let pass.

    CastStore.changes.listen((_) {
      if (_castCounts() == _lastCastCounts) return;
      setLibrary(_stations, _playlists);
    });
  }

  /// A podcast row's second line in the car; null for a station.

  String? _podcastDetails(Station s) => s.isPodcast
      ? podcastCarDetails(availableCount(CastStore.of(s.id)))
      : null;

  String _castCounts() => [
    for (final s in _stations)
      if (s.isPodcast) '${s.id}:${availableCount(CastStore.of(s.id))}',
  ].join(',');

  /// The cast to start for [podcast]: [guid] if given and known, else the
  /// one part heard most recently, else the newest still to hear.

  Cast _castToPlay(Station podcast, String? guid) {
    final casts = CastStore.of(podcast.id);
    final cast = guid == null
        ? castToStart(casts)
        : casts.where((c) => c.guid == guid).firstOrNull;
    if (cast != null) return cast;

    // A chosen episode that has gone is a different story from a podcast
    // with nothing left, and must not be told as one.

    if (guid != null) {
      throw StateError(
        'That episode is no longer listed for ${podcast.name}. Refresh its '
        'Episodes page.',
      );
    }

    throw NothingToPlay(podcast.name, noEpisodes: casts.isEmpty);
  }

  /// What the session should be showing right now: the cast when a podcast
  /// plays, else the station with its song.

  MediaItem _nowItem() {
    final station = _currentStation!;
    final item = _sessionItem(station, _queueParentId, track: _currentTrack);
    final cast = _currentCast;

    return cast == null ? item : castSessionItem(item, station, cast);
  }

  /// Record how far into the current cast the listener is.
  ///
  /// Near enough the end counts as heard (see `isFinished`), and a heard
  /// cast is saved at the start, so playing it again starts it again.
  /// Nothing is saved while the cast is still opening: the player has not
  /// reached the saved place yet, and saving its zero would lose it.

  Future<void> _saveCastPlace() async {
    final station = _currentStation;
    final cast = _currentCast;
    if (station == null || cast == null) return;

    final state = _player.processingState;
    if (state == ProcessingState.idle || state == ProcessingState.loading) {
      return;
    }

    final position = _player.position;

    final finished = isFinished(position, _castLength);
    await CastStore.update(
      station.id,
      cast.guid,
      (c) => c.withState(
        played: finished ? true : null,
        position: finished ? Duration.zero : position,
      ),
    );
  }

  void _startCastSaving() {
    _castSaveTimer?.cancel();
    _castSaveTimer = Timer.periodic(castSaveEvery, (_) {
      if (_player.playing) unawaited(_saveCastPlace());
    });
  }

  /// A cast reached its end: it has been heard. Play the next older one
  /// still to hear, or, when there is none, move on through the queue.

  Future<void> _onCastEnded() async {
    final station = _currentStation;
    final cast = _currentCast;
    if (station == null || cast == null || _stopped || _castEnding) return;
    _castEnding = true;

    _castSaveTimer?.cancel();
    await CastStore.update(
      station.id,
      cast.guid,
      (c) => c.withState(played: true, position: Duration.zero),
    );

    var after = cast.guid;
    for (var tries = 0; tries < _castFailureLimit; tries++) {
      final next = nextCast(CastStore.of(station.id), after: after);
      if (next == null) break;
      try {
        await playStation(
          station,
          queue: _queueStations,
          parentId: _queueParentId,
          castGuid: next.guid,
        );

        return;
      } catch (e) {
        debugPrint('[RadioAudioHandler] cast ${next.guid} would not open: $e');
        after = next.guid;
      }
    }

    await _advanceFromPodcast();
  }

  /// The podcast has nothing more to play: start the next station in the
  /// queue, podcast or radio, as a radio stream that ends moves on.
  ///
  /// 20261018 gjw It used to stop. Wraps round the queue like Next does. A
  /// station that will not start, or a podcast with every episode heard, is
  /// passed over; once the whole queue has been tried, it stops, so a library
  /// with nothing left cannot spin.

  Future<void> _advanceFromPodcast() async {
    final queue = _queueStations;
    final from = _queueIndex;
    final n = queue.length;

    for (var step = 1; from >= 0 && step < n; step++) {
      final next = queue[(from + step) % n];
      try {
        await playStation(next, queue: queue, parentId: _queueParentId);

        return;
      } catch (e) {
        debugPrint('[RadioAudioHandler] ${next.name} would not start: $e');
      }
    }

    await stop();
  }

  /// Seek within the cast on air. Nothing to do for a live station.

  Future<void> _seekCast(Duration target) async {
    if (_currentCast == null) return;
    await _player.seek(clampSeek(target, _castLength));
    _broadcastState(null);
    await _saveCastPlace();
  }

  /// The length of the cast on air, the player's over the feed's (see
  /// [castPlayLength]).

  Duration? get _castLength => castPlayLength(
    measured: _player.duration,
    stated: _currentCast?.duration,
  );

  /// The player has found the cast's length, which the feed did not state
  /// or stated wrongly (an ad-injecting host). Keep it, and republish so
  /// the bar, the car and the lock screen show the real length.

  void _learnCastDuration(Duration? length) {
    final station = _currentStation;
    final cast = _currentCast;
    if (station == null || cast == null || length == null) return;
    if (!lengthNeedsCorrecting(measured: length, stated: cast.duration)) {
      return;
    }

    _currentCast = cast.withDuration(length);
    unawaited(
      CastStore.update(station.id, cast.guid, (c) => c.withDuration(length)),
    );
    mediaItem.add(_nowItem());
    _publishQueue();
  }

  /// The session state while a cast plays: its controls and its timeline.

  void _broadcastCastState(bool playing) {
    final c = castControls(
      playing: playing,
      hasQueue: _queueStations.length > 1,
    );

    playbackState.add(
      playbackState.value.copyWith(
        controls: c.controls,
        systemActions: castSystemActions,
        androidCompactActionIndices: c.compact,
        processingState: _reportedState,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _queueIndex < 0 ? null : _queueIndex,
      ),
    );
  }
}
