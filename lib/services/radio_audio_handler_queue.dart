/// The queue and the song on air, for RadioAudioHandler.
///
// Time-stamp: <Monday 2026-11-23 10:00:00 +1100 Graham Williams>
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

/// The queue Next and Previous walk, and the song on air, for
/// [RadioAudioHandler].
///
/// 20261123 gjw Moved out of radio_audio_handler.dart to keep it under 300
/// lines, as the cast, focus and stream-end parts were.

extension QueueAndTrack on RadioAudioHandler {
  /// The station the browse folders mark as on air: none once stopped.

  String? get _onAirId => _stopped ? null : _currentStation?.id;

  /// Have the car fetch its folders again when the station on air changes,
  /// so the mark moves with it (see `markOnAir`). Not on a new song, nor on
  /// a pause or a buffering stall: only the station or a stop.

  void _markOnAir() {
    final id = _onAirId;
    if (id == _markedOnAir) return;
    _markedOnAir = id;
    for (final e in _childSubjects.entries) {
      if (e.key != browseRootId) e.value.add(<String, dynamic>{});
    }
  }

  /// The station [id] has been deleted: stop it if it is on air, forget it
  /// as the session's station, and take it out of the queue.
  ///
  /// 20261123 gjw Stopping alone was not enough. The media item outlives a
  /// Stop so that Play can re-open the station, and so Play brought the
  /// deleted station straight back.

  Future<void> forgetStation(String id) async {
    if (_currentStation?.id == id) {
      if (!_stopped) await stop();
      _trackSubscription?.cancel();
      _trackSubscription = null;
      _currentStation = null;
      _currentCast = null;
      _currentTrack = null;
      mediaItem.add(null);
      _markOnAir();
    }

    _queueStations = [
      for (final s in _queueStations)
        if (s.id != id) s,
    ];
    final current = _currentStation;
    _queueIndex = current == null
        ? -1
        : _queueStations.indexWhere((s) => s.id == current.id);
    _publishQueue();
  }

  /// Move [delta] stations through the current queue, wrapping at the ends.
  ///
  /// Wrapping matters in the car: a driver pressing Next on the last station
  /// should land back at the first rather than have nothing happen.

  ///
  /// 20261023 gjw A podcast with no episode left to hear is PASSED OVER, as
  /// [_advanceFromPodcast] passes it. Next used to stop at it with nothing
  /// to say, and in the car that looked like the button had broken. Only
  /// that is passed over: a station that will not connect still reports
  /// its error, since the driver should hear that it is gone.

  Future<void> _skipBy(int delta) async {
    if (_queueStations.length < 2 || _queueIndex < 0) return;

    final queue = _queueStations;
    final from = _queueIndex;
    final n = queue.length;

    for (var step = 1; step < n; step++) {
      try {
        await playStation(
          queue[(from + delta * step + n * step) % n],
          queue: queue,
          parentId: _queueParentId,
        );

        return;
      } on NothingToPlay catch (e) {
        debugPrint('[RadioAudioHandler] passing over ${e.podcast}');
      }
    }
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

    // A cast's title is its track; anything a podcast host embeds as ICY
    // metadata is not wanted over it.

    if (station == null || _currentCast != null) return;

    final track = _cleanTrack(title);
    if (track == _currentTrack) return;

    _currentTrack = track;
    mediaItem.add(_nowItem());
    _publishQueue();
  }

  /// Publish the queue, with the station now playing carrying EXACTLY what
  /// [mediaItem] carries.
  ///
  /// 20261006 gjw Android's Bluetooth stack will not hand the car anything
  /// until the session's metadata agrees with the queue row named by the
  /// active queue id. When they disagree it waits, and then gives up:
  ///
  ///     E MediaPlayerWrapper: Timeout while waiting for metadata to sync
  ///       Current Metadata: title="Celine Dion" artist="Celine Dion - ..."
  ///       QueueItem(7):     title="Celine Dion" artist="The United Arab ..."
  ///
  /// They could never agree. The now-playing item puts the song on air in
  /// the artist slot (CLAUDE.md §11) and prefers the user's chosen icon for
  /// artwork, while the queue was built from plain [stationMediaItem] calls
  /// carrying the station's codec-and-bitrate subtitle and its own logo. So
  /// the SAME station appeared twice, described two different ways, and
  /// every station change and every song change cost a ten second stall.
  ///
  /// The row that is playing is therefore the same item the session
  /// publishes. The rest stay as the browse tree builds them — only the
  /// active one is reconciled, and only it has a track to carry.

  void _publishQueue() {
    final items = [
      for (final s in _queueStations)
        stationMediaItem(s, _queueParentId, details: _podcastDetails(s)),
    ];

    if (_currentStation != null &&
        _queueIndex >= 0 &&
        _queueIndex < items.length) {
      items[_queueIndex] = _nowItem();
    }

    // An unchanged queue is not republished. Skipping within a playlist
    // changes which row is active and nothing else, and handing the car a
    // fresh list makes it tear down and rebuild the whole now-playing list.
    //
    // Compared field by field, NOT with listEquals: MediaItem's == is id
    // only (audio_service.dart:667), so a changed artist or artwork — the
    // very thing this republishes for — would compare equal.

    if (_queueSignature(items) == _queueSignature(queue.value)) return;

    queue.add(items);
  }

  static String _queueSignature(List<MediaItem> items) => items
      .map((i) => '${i.id}\u0000${i.artist}\u0000${i.artUri}')
      .join('\u0001');

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
}
