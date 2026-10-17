/// Cast merge — keep the listener's place as feeds and devices change.
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

import 'package:radiopod/models/cast.dart';

/// The most casts kept for one podcast, newest first.
///
/// Some feeds carry a decade of episodes. Every cast of every podcast is
/// rewritten to the Pod on each change, so the back catalogue beyond this is
/// left in the feed rather than carried along for nothing.
///
/// 20261016 gjw Twenty, at Graham's request, down from 300. A subscription
/// is for keeping up, not for working through a back catalogue, and twenty
/// keeps the Casts page short and `casts.ttl` small. It also bounds how far
/// back a podcast plays: once the twentieth newest is heard, there is
/// nothing older to move on to, and playback stops.

const maxCastsPerPodcast = 20;

/// How close to the end counts as having heard a cast.
///
/// Closing music, an outro, a trailer for another show: very few listeners
/// sit through the last half minute, and a cast stopped there should not
/// come back as the next thing to play.

const finishedWithin = Duration(seconds: 30);

/// Merge a freshly fetched feed into the stored casts.
///
/// The feed decides WHICH casts exist and what they say; the stored list
/// decides what the listener has done with them. A cast still in the feed
/// keeps its state. A cast the feed has dropped is kept only if the listener
/// has touched it, since a cast half heard should not vanish mid-listen, and
/// is dropped otherwise. Newest first, capped at [maxCastsPerPodcast].

List<Cast> mergeFeed(List<Cast> stored, List<Cast> fetched) {
  final byGuid = {for (final c in stored) c.guid: c};
  final seen = <String>{};

  final merged = [
    for (final f in fetched)
      if (seen.add(f.guid)) byGuid[f.guid]?.withFeedOf(f) ?? f,
    for (final s in stored)
      if (!seen.contains(s.guid) && s.updatedAt != null) s,
  ]..sort((a, b) => b.published.compareTo(a.published));

  return merged.take(maxCastsPerPodcast).toList();
}

/// Reconcile two copies of the same podcast's casts, cast by cast.
///
/// 20261016 gjw The car records progress on the device, often with no Pod
/// session, and another device may have moved on in the meantime. Whichever
/// copy of a cast was changed more recently wins; a cast present in only one
/// copy is kept. Order is the feed's, newest first.

List<Cast> mergeState(List<Cast> a, List<Cast> b) {
  final byGuid = {for (final c in a) c.guid: c};
  for (final c in b) {
    final other = byGuid[c.guid];
    if (other == null || _newer(c, other)) byGuid[c.guid] = c;
  }

  return byGuid.values.toList()
    ..sort((x, y) => y.published.compareTo(x.published));
}

/// [mergeState] over every podcast in two cast maps.

Map<String, List<Cast>> mergeCastMaps(
  Map<String, List<Cast>> a,
  Map<String, List<Cast>> b,
) => {
  for (final id in {...a.keys, ...b.keys})
    id: mergeState(a[id] ?? const [], b[id] ?? const []),
};

bool _newer(Cast c, Cast than) {
  final t = c.updatedAt, u = than.updatedAt;
  if (t == null) return false;

  return u == null || t.isAfter(u);
}

/// The cast a tap on the podcast starts.
///
/// 20261018 gjw The part-heard cast listened to most recently, so a tap
/// carries on where the listener left off; only when nothing is part heard
/// does it start the newest cast still to hear. Before this a tap always
/// took the newest, so a new cast arriving abandoned the one half heard.
/// Played and switched-off casts are never chosen.

Cast? castToStart(List<Cast> casts) {
  final partHeard =
      casts.where((c) => c.available && c.position > Duration.zero).toList()
        ..sort((a, b) {
          final t = a.updatedAt, u = b.updatedAt;
          if (t == null || u == null) return t == null ? 1 : -1;

          return u.compareTo(t);
        });

  return partHeard.firstOrNull ?? nextCast(casts);
}

/// The cast to play next.
///
/// With no [after], the newest available cast: what a tap on the podcast
/// plays. With [after], the next OLDER available cast, which is how playback
/// works backwards through the back catalogue. Null when nothing is left.

Cast? nextCast(List<Cast> casts, {String? after}) {
  final newestFirst = [...casts]
    ..sort((a, b) => b.published.compareTo(a.published));
  final start = after == null
      ? 0
      : newestFirst.indexWhere((c) => c.guid == after) + 1;
  if (after != null && start == 0) return null;

  return newestFirst.skip(start).where((c) => c.available).firstOrNull;
}

/// The next NEWER available cast than [before], for Previous.

Cast? previousCast(List<Cast> casts, String before) {
  final oldestFirst = [...casts]
    ..sort((a, b) => a.published.compareTo(b.published));
  final start = oldestFirst.indexWhere((c) => c.guid == before) + 1;
  if (start == 0) return null;

  return oldestFirst.skip(start).where((c) => c.available).firstOrNull;
}

/// True when [position] is close enough to the end of [duration] to count
/// as heard. An unknown length is never finished by position alone; the
/// player reporting the end is what marks it then.

///
/// The margin shrinks to a tenth of a short cast, so a two-minute trailer
/// is not counted as heard a few seconds in.

bool isFinished(Duration position, Duration? duration) {
  if (duration == null || duration <= Duration.zero) return false;
  final tenth = duration ~/ 10;
  final margin = tenth < finishedWithin ? tenth : finishedWithin;

  return position >= duration - margin;
}

/// Casts still to hear, for the "5 to play" count.

int availableCount(List<Cast> casts) => casts.where((c) => c.available).length;
