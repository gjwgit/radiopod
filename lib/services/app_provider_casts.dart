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

/// What a refresh of every podcast found: how many podcasts were checked,
/// how many casts were new, and the names of any whose feed failed.

typedef PodcastRefresh = ({int podcasts, int newCasts, List<String> failed});

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

  /// Add the podcasts an OPML file lists, returning how many were new.
  ///
  /// As [importEntries] does for stations: matched on feed URL so a podcast
  /// already saved is not saved twice, and appended rather than put on top,
  /// so a file of fifty does not bury a curated list. The new feeds are then
  /// fetched one at a time in the background; the rows fill in their counts
  /// as they arrive, and a feed that fails waits for the next refresh.

  Future<(int, String?)> importPodcasts(List<OpmlFeed> feeds) async {
    final urls = {for (final s in _stations) s.url};
    final added = [
      for (final f in feeds)
        if (urls.add(f.url))
          Station(
            id: _uuid.v4(),
            name: f.title,
            url: f.url,
            homepage: f.homepage,
            isPodcast: true,
          ),
    ];
    if (added.isEmpty) return (0, null);

    _stations = [..._stations, ...added];
    final error = await _commit();
    if (!_testMode) {
      unawaited(Future.forEach(added, (p) => refreshPodcast(p.id)));
    }

    return (added.length, error);
  }

  /// The library's podcasts as OPML entries, in the list's order.

  List<OpmlFeed> get podcastFeeds => [
    for (final s in _stations)
      if (s.isPodcast) (title: s.name, url: s.url, homepage: s.homepage),
  ];

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

  /// Refresh every podcast's feed: after a load, so new casts appear without
  /// the listener asking, and from the toolbar's Refresh podcasts.
  ///
  /// One run at a time. A tap while the run after a load is still going
  /// waits for that run rather than fetching every feed twice. A feed that
  /// fails leaves its stored casts as they were and is named in the result.

  Future<PodcastRefresh> refreshAllPodcasts() => _podcastRefresh ??=
      _refreshEachPodcast().whenComplete(() => _podcastRefresh = null);

  Future<PodcastRefresh> _refreshEachPodcast() async {
    final podcasts = _stations.where((s) => s.isPodcast).toList();
    if (_testMode) {
      return (podcasts: podcasts.length, newCasts: 0, failed: <String>[]);
    }
    await syncCasts(force: true);

    var newCasts = 0;
    final failed = <String>[];
    for (final p in podcasts) {
      final before = {for (final c in castsOf(p.id)) c.guid};
      if (await refreshPodcast(p.id) != null) {
        failed.add(p.name);
        continue;
      }
      newCasts += castsOf(p.id).where((c) => !before.contains(c.guid)).length;
    }

    return (podcasts: podcasts.length, newCasts: newCasts, failed: failed);
  }

  /// Write any progress not yet on the Pod, now. Called as the app leaves
  /// the screen, when it may be closed or frozen before the timer fires.

  Future<void> flushCasts() async {
    _castPodWrite?.cancel();
    _castPodWrite = null;
    await _saveCastsToPod();
  }

  /// Bring in progress made on another device, and send this one's.
  ///
  /// 20261017 gjw The casts were read from the Pod only when the library
  /// loaded, so a desktop left open never saw what was heard on the phone.
  /// Called when the app comes back to the screen and before Refresh
  /// podcasts. At most every 30 seconds unless [force]d: on the desktop the
  /// app "resumes" each time its window regains focus.

  Future<void> syncCasts({bool force = false}) async {
    if (_testMode || _source != LibrarySource.pod) return;
    final now = DateTime.now();
    final last = _castsSyncedAt;
    if (!force && last != null && now.difference(last).inSeconds < 30) return;
    _castsSyncedAt = now;

    try {
      await _loadCasts();
      _notify();
      await _pushToPlayer();
      await _saveCastsToPod();
    } catch (e) {
      debugPrint('[AppProvider] cast sync failed: $e');
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
