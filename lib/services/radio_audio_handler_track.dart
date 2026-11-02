/// RadioAudioHandler's track on air — the song a station announces.
///
// Time-stamp: <Monday 2026-11-02 06:00:00 +1100 Graham Williams>
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

/// How [RadioAudioHandler] learns and shows the song on air.
///
/// A part of the handler so it can reach the playback state,
/// and kept apart so radio_audio_handler.dart stays under the line limit.

extension TrackHandling on RadioAudioHandler {
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
