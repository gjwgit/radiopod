/// Cast playback — what the media session says while a podcast plays.
///
// Time-stamp: <Sunday 2026-10-18 21:32:12 +1100 Graham Williams>
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

/// How far back a resumed cast starts from where it was left.
///
/// 20261016 gjw A cast picked up again exactly where it stopped starts
/// mid-word, with the listener having lost the thread; five seconds is enough
/// to pick it back up.

const castResumeBack = Duration(seconds: 5);

/// Where to resume a cast left at [position]: [castResumeBack] before it,
/// and never before the start.

Duration resumeFrom(Duration position) =>
    position <= castResumeBack ? Duration.zero : position - castResumeBack;

/// A podcast was started with nothing it can play: no episodes yet, or
/// every one heard or switched off.
///
/// 20261018 gjw Its own type, not a StateError, so the screens can tell it
/// from a fault. It was reported as "The stream could not be reached", with
/// advice to find the station again in Search, when all that had happened
/// was that every episode had been heard.

class NothingToPlay implements Exception {
  final String podcast;

  /// True when the podcast has no episodes at all, rather than none left.

  final bool noEpisodes;

  const NothingToPlay(this.podcast, {required this.noEpisodes});

  String get title => noEpisodes ? 'No episodes yet' : 'Nothing left to play';

  String get message => noEpisodes
      ? '$podcast has no episodes yet. Open its Episodes page, the list '
            'button on its row, and Refresh.'
      : 'Every episode of $podcast has been heard or switched off. New '
            'episodes are fetched as they are published.\n\n'
            'To hear one again, open its Episodes page, the list button on '
            'its row, and choose Mark as not played from the episode\'s menu.';

  @override
  String toString() => message;
}

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
/// Next and Previous move through the station queue, as for a station,
/// and are offered when it holds another.

({List<MediaControl> controls, List<int> compact}) castControls({
  required bool playing,
  required bool hasQueue,
}) {
  final controls = [
    if (hasQueue) MediaControl.skipToPrevious,
    MediaControl.rewind,
    if (playing) MediaControl.pause else MediaControl.play,
    MediaControl.fastForward,
    if (hasQueue) MediaControl.skipToNext,
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

/// The length of the cast on air: what the player [measured], once it has,
/// else what the feed [stated].
///
/// 20261018 gjw THE FEED'S LENGTH IS ONLY A HINT. Hosts that splice adverts
/// into the audio as they serve it (Simplecast's `-injected` host, for one)
/// state the length WITHOUT the ads: Daily Mass Readings said 5:48 and sent
/// 6:18. Trusting it drew the bar short, made Forward clamp to 5:47 and so
/// jump BACK, and marked the episode heard, its place reset, a minute
/// before it ended.

Duration? castPlayLength({Duration? measured, Duration? stated}) =>
    measured != null && measured > Duration.zero ? measured : stated;

/// Whether the player's [measured] length should replace the [stated] one:
/// when there is none, or it is out by more than a couple of seconds (an
/// estimate from the bitrate may differ by a fraction of one).

bool lengthNeedsCorrecting({required Duration measured, Duration? stated}) =>
    measured > Duration.zero &&
    (stated == null || (measured - stated).abs() > const Duration(seconds: 2));

/// [target] kept within the cast. A jump past the end lands just short of
/// it, so the cast finishes and the next one plays, rather than the player
/// being asked to seek beyond the audio.

Duration clampSeek(Duration target, Duration? length) {
  if (target < Duration.zero) return Duration.zero;
  if (length == null || length <= Duration.zero) return target;
  final last = length - const Duration(seconds: 1);

  return target > last ? last : target;
}
