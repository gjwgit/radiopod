/// Cast playback — what the media session says while a podcast plays.
///
// Time-stamp: <Friday 2026-10-16 06:00:00 +1100 Graham Williams>
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

library;

import 'package:audio_service/audio_service.dart';

import 'package:radiopod/models/cast.dart';
import 'package:radiopod/models/station.dart';

/// How far the forward button jumps: past a typical ad break segment.

const castSkipForward = Duration(seconds: 30);

/// How far back the rewind button jumps: enough to re-hear a sentence.

const castSkipBack = Duration(seconds: 15);

/// How often a playing cast's position is saved, so a phone that dies or a
/// car that is switched off loses at most this much.

const castSaveEvery = Duration(seconds: 15);

/// The session's media item for [cast] of [podcast].
///
/// 20261016 gjw Built FROM the podcast's own item, keeping its id, so the
/// list, the car and CarPlay go on finding the podcast row by
/// `extras['stationId']` exactly as they find a station. The cast title
/// becomes the title, the podcast moves to the artist line, and the length
/// is given so the car and the lock screen draw a seek bar. `track` carries
/// the cast title too, which is what the podcast's row in the app shows
/// under its name while it plays, as a station shows its song.

MediaItem castSessionItem(MediaItem podcastItem, Station podcast, Cast cast) =>
    podcastItem.copyWith(
      title: cast.title,
      artist: podcast.name,
      album: podcast.author ?? podcast.name,
      duration: cast.duration,
      isLive: false,
      extras: {
        ...?podcastItem.extras,
        'castGuid': cast.guid,
        'track': cast.title,
      },
    );

/// The transport controls for a cast, which unlike a station has a
/// timeline: back, play or PAUSE (a pause keeps the place), forward.
/// Next and Previous move to the older or newer cast, and are offered only
/// when there is one.

({List<MediaControl> controls, List<int> compact}) castControls({
  required bool playing,
  required bool hasOlder,
  required bool hasNewer,
}) {
  final controls = [
    if (hasNewer) MediaControl.skipToPrevious,
    MediaControl.rewind,
    if (playing) MediaControl.pause else MediaControl.play,
    MediaControl.fastForward,
    if (hasOlder) MediaControl.skipToNext,
  ];
  final rewind = controls.indexOf(MediaControl.rewind);

  return (controls: controls, compact: [rewind, rewind + 1, rewind + 2]);
}

/// What the system may ask of a cast: everything a timeline allows.

const castSystemActions = {
  MediaAction.play,
  MediaAction.pause,
  MediaAction.stop,
  MediaAction.seek,
  MediaAction.fastForward,
  MediaAction.rewind,
};

/// [target] kept within the cast. A jump past the end lands just short of
/// it, so the cast finishes and the next one plays, rather than the player
/// being asked to seek beyond the audio.

Duration clampSeek(Duration target, Duration? length) {
  if (target < Duration.zero) return Duration.zero;
  if (length == null || length <= Duration.zero) return target;
  final last = length - const Duration(seconds: 1);

  return target > last ? last : target;
}
