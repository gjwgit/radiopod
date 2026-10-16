/// AppProvider's podcast half — casts, feeds and the listener's progress.
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

part of 'app_provider.dart';

/// Podcast operations on the library.
///
/// 20261016 gjw A part of AppProvider rather than a class of its own so the
/// cast mutations go through the same notify → player → save path as every
/// other (CLAUDE.md §5), without app_provider.dart growing past reading.
/// Cast changes save only the casts: rewriting the station library for a
/// ticked switch would be a Pod write for nothing.

extension PodcastLibrary on AppProvider {
  /// One podcast's casts, newest first.

  List<Cast> castsOf(String podcastId) => CastStore.of(podcastId);

  /// How many of a podcast's casts are still to be heard.

  int castsToPlay(String podcastId) => availableCount(castsOf(podcastId));

  /// Never play this cast, or play it again.

  Future<String?> setCastDisabled(String podcastId, String guid, bool off) =>
      _changeCast(podcastId, guid, (c) => c.withState(disabled: off));

  /// Skip every cast of a podcast, or none. One store write and one Pod
  /// write, rather than one of each per cast.

  Future<String?> setAllCastsDisabled(String podcastId, bool off) async {
    final now = DateTime.now().toUtc();
    await CastStore.put(podcastId, [
      for (final c in castsOf(podcastId))
        c.disabled == off ? c : c.withState(disabled: off, at: now),
    ]);
    _castsDirty = true;

    return _commitCasts();
  }

  /// Mark a cast heard, greying it out, or not yet heard. Either way it
  /// starts from the beginning next time.

  Future<String?> setCastPlayed(String podcastId, String guid, bool played) =>
      _changeCast(
        podcastId,
        guid,
        (c) => c.withState(played: played, position: Duration.zero),
      );

  /// Save a podcast found through Search, with its casts.
  ///
  /// The feed is fetched straight away so the row shows a count and a tap
  /// has something to play. A feed that cannot be fetched still leaves the
  /// podcast saved: it may only be offline, and Refresh will try again.

  Future<String?> addPodcast(Station podcast) async {
    final error = await addStation(podcast);
    if (error != null) return error;

    return refreshPodcast(podcast.id);
  }

  /// Play one particular cast, then carry on backwards from it.

  Future<void> playCast(String podcastId, String guid) async {
    final podcast = _stations.where((s) => s.id == podcastId).firstOrNull;
    if (podcast == null) return;
    await Player.handler.playStation(podcast, castGuid: guid);
  }

  /// Play the latest cast of a podcast that is NOT saved, from Search.
  ///
  /// Its casts go into the store under the result's id so the player can
  /// find them; they are never written to the Pod, which carries only the
  /// library's podcasts, and they become the podcast's casts if it is then
  /// saved — keeping any progress made while auditioning it.

  Future<void> previewPodcast(Station podcast) async {
    final feed = await fetchFeed(podcast.url);
    await CastStore.put(
      podcast.id,
      mergeFeed(CastStore.of(podcast.id), feed.casts),
    );
    await play(podcast);
  }

  /// Fetch a podcast's feed and merge it into the stored casts.
  ///
  /// Returns a message when the feed could not be fetched or read, which
  /// leaves the stored casts exactly as they were.

  Future<String?> refreshPodcast(String podcastId) async {
    final podcast = _stations.where((s) => s.id == podcastId).firstOrNull;
    if (podcast == null || !podcast.isPodcast) return null;

    try {
      final feed = await fetchFeed(podcast.url);
      await CastStore.put(
        podcastId,
        mergeFeed(CastStore.of(podcastId), feed.casts),
      );
      _castsDirty = true;

      // Fill in what Search could not supply, never overwrite what the
      // listener chose.

      if (podcast.author == null && feed.author != null ||
          podcast.favicon == null && feed.image != null) {
        _stations = [
          for (final s in _stations)
            s.id == podcastId
                ? s.copyWith(
                    author: s.author ?? feed.author,
                    favicon: s.favicon ?? feed.image,
                  )
                : s,
        ];

        return await _commit();
      }

      return await _commitCasts();
    } catch (e) {
      debugPrint('[AppProvider] feed refresh failed (${podcast.url}): $e');

      return 'Could not fetch ${podcast.name}. $e';
    }
  }

  /// Refresh every podcast's feed, quietly. Run after a load, so new casts
  /// appear without the listener asking. Failures leave the stored casts.

  Future<void> refreshAllPodcasts() async {
    if (_testMode) return;
    for (final p in _stations.where((s) => s.isPodcast).toList()) {
      await refreshPodcast(p.id);
    }
  }

  Future<String?> _changeCast(
    String podcastId,
    String guid,
    Cast Function(Cast) change,
  ) async {
    await CastStore.update(podcastId, guid, change);
    _castsDirty = true;

    return _commitCasts();
  }

  /// [AppProvider._commit] for a change to casts alone.

  Future<String?> _commitCasts() async {
    _notify();
    await _pushToPlayer();

    return _saveCastsToPod();
  }

  /// Read the casts: the device copy, reconciled with the Pod's when one is
  /// in use. Progress recorded in the car without a Pod session is newer
  /// than the Pod's copy, wins cast by cast, and is written back.

  Future<void> _loadCasts() async {
    await CastStore.load();
    if (_source != LibrarySource.pod) return;

    final podCasts = decodeCasts(await PodService.load(castsFileName));
    final merged = mergeCastMaps(podCasts, CastStore.all);
    await CastStore.replaceAll(merged);
    if (encodeCasts(_podcastsOnly(merged)) !=
        encodeCasts(_podcastsOnly(podCasts))) {
      _castsDirty = true;
    }
  }

  /// Write `casts.ttl` when the casts have changed and a Pod is in use.
  ///
  /// Only podcasts in the library are written. The device may hold casts of
  /// a podcast saved while logged out on a borrowed phone; what someone else
  /// listened to does not belong in this Pod.

  Future<String?> _saveCastsToPod() async {
    if (_testMode || !_castsDirty || _source != LibrarySource.pod) {
      return null;
    }

    final error = await PodService.save(
      castsFileName,
      encodeCasts(_podcastsOnly(CastStore.all)),
    );
    if (error == null) _castsDirty = false;

    return error;
  }

  Map<String, List<Cast>> _podcastsOnly(Map<String, List<Cast>> casts) {
    final ids = {
      for (final s in _stations)
        if (s.isPodcast) s.id,
    };

    return {
      for (final e in casts.entries)
        if (ids.contains(e.key)) e.key: e.value,
    };
  }
}
