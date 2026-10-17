/// AppProvider — state management for the RadioPod station library.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:solidpod/solidpod.dart' show isUserLoggedIn;
import 'package:uuid/uuid.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/constants/demo_stations.dart';
import 'package:radiopod/models/cast.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/cast_store.dart';
import 'package:radiopod/services/demo_seed.dart';
import 'package:radiopod/services/local_store.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/services/pod_service.dart';
import 'package:radiopod/services/podcast_feed.dart';
import 'package:radiopod/services/station_icon_cache.dart';
import 'package:radiopod/utils/cast_merge.dart';
import 'package:radiopod/utils/opml.dart';
import 'package:radiopod/utils/playlist_file.dart';

part 'app_provider_casts.dart';
part 'app_provider_playlists.dart';

const _uuid = Uuid();

/// Phases of app startup, used to show phase-aware busy feedback while the
/// Pod is unlocked and the initial data is pulled.

enum StartupPhase { idle, unlocking, loading, ready }

/// Where the library is being read from and written to.
///
/// Tapping Continue at the login screen is a supported way to use RadioPod,
/// not a degraded one, so there are two real homes for the data rather than
/// one home and an error state.

enum LibrarySource {
  /// Logged out. SharedPreferences on this device is the library.

  local,

  /// Logged in. The Solid Pod is the library, encrypted, and the device copy
  /// is kept as a mirror for Android Auto.
  pod,
}

/// App-level state: the station library, the playlists, and where they live.
///
/// Every mutation goes through [_commit], which notifies listeners, hands
/// the new library to the audio handler (so Android Auto and the
/// notification see it immediately) and persists it. That one path is why a
/// station added on the phone appears in the car without a restart.
///
/// WHERE THE DATA LIVES depends on whether there is a Solid login, and
/// [source] is the single answer. Logged out, the device is the library and
/// nothing is sent anywhere. Logged in, the Pod is the library and the
/// device copy becomes a mirror for the car. The switch happens in
/// [resolveSource], which every load consults, so no screen has to think
/// about it.

class AppProvider extends ChangeNotifier {
  AppProvider() {
    // 20261016 gjw The audio handler records each cast's progress straight
    // into CastStore. Listening here keeps the counts on the podcast rows
    // current, and carries that progress to the Pod at most a minute after
    // it changed, so a cast playing does not mean a Pod write every fifteen
    // seconds. 20261017 gjw A minute after the FIRST unsaved change, not
    // the last: a cast saves its place every fifteen seconds, so restarting
    // the timer on each change meant nothing reached the Pod while one
    // played, and progress on the phone never showed on the desktop.

    _castChanges = CastStore.changes.listen((_) {
      _castsDirty = true;
      notifyListeners();
      _castPodWrite ??= Timer(const Duration(seconds: 60), () {
        _castPodWrite = null;
        unawaited(_saveCastsToPod());
      });
    });
  }

  late final StreamSubscription<String> _castChanges;
  Timer? _castPodWrite;

  @override
  void dispose() {
    _castChanges.cancel();
    _castPodWrite?.cancel();
    super.dispose();
  }

  List<Station> _stations = [];
  List<Playlist> _playlists = [];
  bool _loading = false;
  bool _isKeySaved = false;
  String? _error;
  StartupPhase _startupPhase = StartupPhase.idle;

  /// Where the library currently lives. Local until a login is confirmed,
  /// so a first frame drawn before [resolveSource] has run never implies a
  /// Pod that may not be there.

  LibrarySource _source = LibrarySource.local;

  /// When true, Pod writes are skipped. Set by [loadForTest] so tests run
  /// without a live Pod.

  bool _testMode = false;

  /// 20261002 gjw True once the user has dismissed the security key prompt.
  ///
  /// THIS IS WHAT BREAKS AN OTHERWISE INFINITE LOOP. solidui's security key
  /// screen is pushed fullscreen, and its Cancel does
  /// `pushReplacement(context, widget.child)` — where the child is the
  /// AppScaffold the prompt was asked for. Cancel therefore does not cancel:
  /// it builds a NEW AppScaffold, whose initState asks again, for ever. The
  /// Pod session outlives a restart, so the app could not be opened at all.
  ///
  /// Lives HERE, not in the scaffold's State, precisely because the scaffold
  /// is the thing being rebuilt. AppProvider sits above MaterialApp in
  /// main.dart and survives the replacement.
  ///
  /// Session-scoped on purpose. The next launch asks once more, which is
  /// right: someone who cancelled today may want to unlock tomorrow. Within
  /// a session the key can still be set from the status bar.
  ///
  /// [_keyPromptShown] is set BEFORE the prompt is awaited, not after. The
  /// replacement scaffold starts its own _initKeys while this one is still
  /// suspended on that await, so a flag set afterwards can lose the race and
  /// let a second prompt through.

  bool _keyPromptShown = false;
  bool _keyPromptDeclined = false;

  /// 20261004 gjw True when a WebID is stored but the session behind it is no
  /// longer usable — the access token has expired.
  ///
  /// solidpod's `getWebId()` only reports that a WebID is in secure storage;
  /// `isUserLoggedIn()` additionally requires a non-expired access token. The
  /// two disagree exactly here, and treating the WebID alone as proof of a
  /// session asked for a security key that could not possibly work: every
  /// operation behind it then failed with "Authentication data not
  /// available. Please login first", while the prompt helpfully displayed the
  /// WebID the user was supposedly logged in as.

  bool _sessionExpired = false;

  /// True when the casts have changed since `casts.ttl` was last written.
  /// The cast list is the largest thing RadioPod stores, so it is written to
  /// the Pod only when it has actually changed, not on every station edit.

  bool _castsDirty = false;

  /// When the casts were last brought in from the Pod; see [syncCasts].

  DateTime? _castsSyncedAt;

  /// The refresh of every podcast under way, if one is. See
  /// [PodcastLibrary.refreshAllPodcasts].

  Future<PodcastRefresh>? _podcastRefresh;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Station> get stations => _stations;
  List<Playlist> get playlists => _playlists;
  bool get loading => _loading;
  bool get isKeySaved => _isKeySaved;
  String? get error => _error;
  StartupPhase get startupPhase => _startupPhase;
  LibrarySource get source => _source;

  /// True when the library is being kept on this device rather than on a Pod.

  bool get isLocal => _source == LibrarySource.local;

  /// True once the security key prompt has been put up this session, whatever
  /// came of it. Checked before prompting again.

  bool get keyPromptShown => _keyPromptShown;

  /// True once the security key prompt has been dismissed this session.

  bool get keyPromptDeclined => _keyPromptDeclined;

  /// True when a stored WebID has outlived its session. The library falls
  /// back to this device until the user logs in again.

  bool get sessionExpired => _sessionExpired;

  /// Record an expired session: no key prompt, and the device library.
  ///
  /// Also claims the key prompt, so nothing later in startup puts it up. A
  /// key cannot be verified without a session, so asking only wastes the
  /// user's time and then fails.

  void markSessionExpired() {
    if (_sessionExpired) return;
    _sessionExpired = true;
    _keyPromptShown = true;
    _keyPromptDeclined = true;
    _source = LibrarySource.local;
    notifyListeners();
  }

  /// Claim the one security key prompt this session allows.
  ///
  /// Returns false when the prompt has already been shown, so the caller can
  /// skip it. Call this BEFORE awaiting the prompt — see [_keyPromptShown].

  bool claimKeyPrompt() {
    if (_keyPromptShown) return false;
    _keyPromptShown = true;

    return true;
  }

  /// Record that the user dismissed the security key prompt, and fall back to
  /// the device library so the app is usable rather than stuck.
  ///
  /// Without the fallback every load would still take the Pod branch and
  /// throw "You must first set the security key!" twice over — once for
  /// stations.ttl and once for playlists.ttl — leaving an empty app and a
  /// pair of errors in the log.

  void declineKeyPrompt() {
    if (_keyPromptDeclined) return;
    _keyPromptDeclined = true;
    _source = LibrarySource.local;
    notifyListeners();
  }

  /// True while the app is unlocking the Pod or loading initial data.

  bool get isStartingUp =>
      _startupPhase == StartupPhase.unlocking ||
      _startupPhase == StartupPhase.loading;

  /// Single source of truth for "show a busy indicator, not content". True
  /// during the security-key unlock phase, the initial load, AND any later
  /// load, so the empty state never flashes between startup phases.

  bool get busy => _loading || isStartingUp;

  /// The stations of [playlist], in playlist order, skipping ids whose
  /// station has been deleted from the library.

  List<Station> stationsOf(Playlist playlist) {
    final byId = {for (final s in _stations) s.id: s};

    return [
      for (final id in playlist.stationIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Move a station within the library.
  ///
  /// THE LIST ORDER IS THE USER'S ORDER. There is no separate sort field and
  /// no alphabetical default: `_stations` is stored, and reloaded, in the
  /// order it is shown, so dragging a station to the top keeps it at the top
  /// on the next launch, on the other devices sharing the Pod, and in the
  /// car.
  ///
  /// Indices are positions in the whole library, which is why the Stations
  /// screen only offers dragging when its filter box is empty — with a
  /// filter applied the visible positions say nothing about where the hidden
  /// stations sit.
  ///
  /// [newIndex] is taken from `onReorderItem`, which has already adjusted for
  /// the removed item, so it is used as-is. The older `onReorder` callback
  /// needs a further -1 and is deprecated; do not switch back to it.

  Future<String?> reorderStation(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return Future.value();

    final list = List<Station>.from(_stations);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), moved);
    _stations = list;

    return _commit();
  }

  void setStartupPhase(StartupPhase phase) {
    _startupPhase = phase;
    notifyListeners();
  }

  /// Update the security-key saved state. Notifies listeners so the status
  /// bar badge in AppScaffold re-renders.

  void setKeySaved(bool saved) {
    if (_isKeySaved == saved) return;
    _isKeySaved = saved;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Stations ──────────────────────────────────────────────────────────────

  /// Add [station] to the library, or return null unchanged if a station
  /// with the same stream URL is already saved.
  ///
  /// GOES TO THE TOP, not the end. A station saved from Search has just been
  /// chosen deliberately, and the list is the user's own order, so it lands
  /// where it can be seen and dragged into place rather than at the bottom
  /// of a library that may need scrolling to reach. It is also the first
  /// thing Android Auto's All Stations list opens on.
  ///
  /// [importEntries] deliberately still appends: a playlist file brings in
  /// stations wholesale, and putting fifty of them above a curated top would
  /// bury it.
  ///
  /// Matching on URL rather than name is what stops the same station being
  /// saved twice from two different Radio-Browser entries, which is common
  /// for popular stations.

  Future<String?> addStation(Station station) {
    if (_stations.any((s) => s.url == station.url)) return Future.value();
    _stations = [station, ..._stations];

    return _commit();
  }

  Future<String?> updateStation(Station updated) {
    _stations = [for (final s in _stations) s.id == updated.id ? updated : s];

    return _commit();
  }

  /// Delete a station and remove it from every playlist that referenced it.

  Future<String?> deleteStation(String id) {
    _stations = _stations.where((s) => s.id != id).toList();
    _playlists = [
      for (final p in _playlists)
        p.copyWith(stationIds: p.stationIds.where((i) => i != id).toList()),
    ];

    return _commit();
  }

  /// Set whether a station is reconnected when its stream ends.
  ///
  /// See [Station.reconnectOnEnd]: on for a continuous station whose
  /// connection drops between programmes, off for one that genuinely
  /// finishes and should hand over to the next station.

  Future<String?> setReconnectOnEnd(String id, bool value) {
    _stations = [
      for (final s in _stations)
        s.id == id ? s.copyWith(reconnectOnEnd: value) : s,
    ];

    return _commit();
  }

  /// True when [url] is already in the library, so Search can show a station
  /// as saved rather than offering to save it twice.

  bool isSaved(String url) => _stations.any((s) => s.url == url);

  // ── Import ────────────────────────────────────────────────────────────────

  /// Add the stations of an imported playlist file to the library and, when
  /// [playlistName] is given, group them into a new playlist.
  ///
  /// Entries whose URL is already saved reuse the existing station rather
  /// than creating a duplicate, so re-importing a file the user has already
  /// imported grows the playlist but not the library. Returns the number of
  /// stations that were genuinely new.

  Future<(int, String?)> importEntries(
    List<PlaylistEntry> entries, {
    String? playlistName,
  }) async {
    final byUrl = {for (final s in _stations) s.url: s};
    final added = <Station>[];
    final ids = <String>[];

    for (final e in entries) {
      final existing = byUrl[e.url];
      if (existing != null) {
        if (!ids.contains(existing.id)) ids.add(existing.id);
        continue;
      }
      final station = Station(id: _uuid.v4(), name: e.name, url: e.url);
      byUrl[e.url] = station;
      added.add(station);
      ids.add(station.id);
    }

    _stations = [..._stations, ...added];
    if (playlistName != null && ids.isNotEmpty) {
      _playlists = [
        ..._playlists,
        Playlist(id: _uuid.v4(), name: playlistName, stationIds: ids),
      ];
    }

    return (added.length, await _commit());
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Start [station] through the audio handler, with Next and Previous
  /// moving through [queue] — the list the user picked it from.

  Future<void> play(Station station, {List<Station>? queue}) async {
    if (station.isPodcast) await _syncBeforePlay();
    await Player.handler.playStation(station, queue: queue);
  }

  // ── Loading and saving ────────────────────────────────────────────────────

  /// Ask solidpod whether there is a login, and set [source] from the answer.
  ///
  /// Called before every load rather than cached, because the answer changes
  /// while the app is running: the user can log in from the profile menu
  /// long after tapping Continue, and can log out again.

  /// Record a login state the caller already knows, WITHOUT asking solidpod.
  ///
  /// EVERY CALL TO [resolveSource] COSTS KEYCHAIN ACCESS. On macOS
  /// `isUserLoggedIn` begins with solidpod's `chooseSecureStorageOptions`,
  /// which probes the keychain with a real write and delete, and then reads
  /// the WebID and the access token. Until a Developer ID build carries an
  /// embedded provisioning profile those calls land in the legacy login
  /// keychain, and macOS asks for the keychain password EACH TIME.
  ///
  /// So a caller that already knows the answer — AppScaffold has just called
  /// `getWebId()` — says so here instead of making solidpod work it out
  /// again. Someone who tapped Continue never reaches the keychain at all.

  /// 20261002 gjw A declined key pins the source to local for the session.
  /// Without that, the scaffold rebuilt by Cancel calls this on the way in,
  /// flips the source back to pod, and every load throws "You must first set
  /// the security key!" again — the loop's other half.

  void setLoggedIn(bool loggedIn) {
    _source = loggedIn && !_keyPromptDeclined
        ? LibrarySource.pod
        : LibrarySource.local;
    notifyListeners();
  }

  Future<LibrarySource> resolveSource() async {
    if (_testMode) return _source;

    try {
      _source = await isUserLoggedIn()
          ? LibrarySource.pod
          : LibrarySource.local;
    } catch (e) {
      // Treat an unanswerable question as logged out. Falling back to the
      // device keeps the app usable and, more importantly, never writes to
      // a Pod we are not sure about.

      debugPrint('[AppProvider] could not determine login state: $e');
      _source = LibrarySource.local;
    }

    return _source;
  }

  /// Load the library from wherever it currently lives.
  ///
  /// This is the one entry point the UI calls. It re-checks the login state
  /// first, so logging in and pressing refresh is enough to switch from the
  /// device copy to the Pod.

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 20260922 gjw Uses the source ALREADY resolved, and does not ask
      // solidpod again. load() runs at startup, on Refresh from Pod and
      // after every login change; re-resolving here meant a keychain probe
      // each time, which on a macOS build with no provisioning profile is a
      // keychain password prompt each time. The login state is settled once,
      // by AppScaffold, and changes only through setLoggedIn or an explicit
      // resolveSource.

      if (_source == LibrarySource.pod) {
        _stations = _decode(
          await PodService.load(stationsFileName),
          Station.fromJson,
        );
        _playlists = _decode(
          await PodService.load(playlistsFileName),
          Playlist.fromJson,
        );

        // Refresh the device mirror so the car can browse the Pod library
        // before the next login completes. A library saved here while logged
        // out is held back first, not overwritten; see LocalStore.

        await LocalStore.save(_stations, _playlists, fromPod: true);
      } else {
        final (stations, playlists) = await LocalStore.load();
        _stations = stations;
        _playlists = playlists;
      }
      await _loadCasts();
      await _pushToPlayer();

      // Send back progress the Pod has not seen, such as an episode heard
      // in the car. Writes nothing when the Pod was already up to date.

      unawaited(_saveCastsToPod());

      // INSIDE the try, so it runs only after a load that actually
      // succeeded. A Pod that failed to answer also leaves _stations empty,
      // and seeding there would drop three stations on top of a library
      // that merely could not be reached.

      if (!_testMode) await seedIfEmpty();

      // New casts arrive without the listener asking. Not awaited: the
      // list is drawn from the stored casts at once, and the counts update
      // as each feed answers.

      if (!_testMode) unawaited(refreshAllPodcasts());
    } catch (e) {
      _error = _source == LibrarySource.pod
          ? 'Could not load your stations from the Pod.'
          : 'Could not load your stations from this device.';
      debugPrint('[AppProvider] load error: $e');
    } finally {
      // Always clear loading so the UI can't hang on the busy indicator.

      _loading = false;
      notifyListeners();
    }
  }

  /// Put the starter stations into a library that has never had any.
  ///
  /// 20261008 gjw A first run opening on an empty list says nothing about
  /// what the app is for. Three stations that play straight away do, and
  /// they are the quickest way to see Playlists, the car and the sleep timer
  /// doing something.
  ///
  /// Guarded on [DemoSeed], not merely on the list being empty: see there
  /// for why deleting your last station must not bring them back.
  ///
  /// Goes through [_commit] like every other mutation (§5), so the stations
  /// are written to wherever the library lives and reach the player — a car
  /// browsing the tree sees them without a restart.

  @visibleForTesting
  Future<void> seedIfEmpty() async {
    if (await DemoSeed.done) return;

    // A library that HAS stations retires the offer for good. Otherwise
    // someone who has had their own stations all along, and one day deletes
    // the last of them, would be handed three of ours on the next start-up
    // — exactly the resurrection DemoSeed exists to prevent. They have seen
    // what the app does; they do not need the demonstration.

    if (_stations.isNotEmpty) {
      await DemoSeed.markDone();

      return;
    }

    // Mark BEFORE adding. _commit can fail to reach a Pod, and a failure
    // that left the flag unset would seed again on every start-up until a
    // write happened to succeed.

    await DemoSeed.markDone();

    _stations = [...demoStations];
    await _commit();
  }

  /// Reload and report whether anything actually changed, so the refresh
  /// button can say "already up to date" rather than nothing.

  Future<bool> refreshFromPod() async {
    if (_testMode) return false;
    final before = _signature();
    await load();

    return _signature() != before;
  }

  /// Persist the library to wherever it lives, returning an error or null.
  ///
  /// The device copy is written either way — it is the library when logged
  /// out and the car's mirror when logged in — and only the Pod write can
  /// fail in a way worth reporting.

  Future<String?> saveAll() async {
    if (_testMode) return null;

    final onPod = _source == LibrarySource.pod;
    await LocalStore.save(_stations, _playlists, fromPod: onPod);
    if (!onPod) return null;

    final stationsErr = await PodService.save(
      stationsFileName,
      jsonEncode([for (final s in _stations) s.toJson()]),
    );
    final playlistsErr = await PodService.save(
      playlistsFileName,
      jsonEncode([for (final p in _playlists) p.toJson()]),
    );
    final err = stationsErr ?? playlistsErr ?? await _saveCastsToPod();
    if (err != null) {
      _error = err;
      notifyListeners();
    }

    return err;
  }

  /// Copy everything held on this device up to the Pod, merging rather than
  /// replacing, and return how many stations were new to the Pod.
  ///
  /// Deliberately NOT automatic on login. A library built while logged out
  /// is not obviously meant for the Pod — a shared or borrowed device is
  /// exactly where someone taps Continue — so Settings offers this as a
  /// button and nothing moves without a deliberate tap.
  ///
  /// Stations already on the Pod are matched by stream URL and left alone,
  /// so pressing it twice is harmless. Playlists are matched by name: one
  /// the Pod does not have is added, one it already has is left as the Pod
  /// has it rather than merged, which keeps the rule easy to state.

  Future<(int, String?)> copyLocalToPod() async {
    if (_source != LibrarySource.pod) {
      return (0, 'Log in to your Pod first.');
    }

    final (localStations, localPlaylists) = await LocalStore.loadHeld();
    final byUrl = {for (final s in _stations) s.url: s};
    final idMap = <String, String>{};
    final added = <Station>[];

    for (final s in localStations) {
      final existing = byUrl[s.url];
      if (existing != null) {
        idMap[s.id] = existing.id;
        continue;
      }
      byUrl[s.url] = s;
      idMap[s.id] = s.id;
      added.add(s);
    }

    final names = {for (final p in _playlists) p.name};
    final newPlaylists = [
      for (final p in localPlaylists)
        if (!names.contains(p.name))
          p.copyWith(
            stationIds: [
              for (final id in p.stationIds)
                if (idMap[id] != null) idMap[id]!,
            ],
          ),
    ];

    if (added.isEmpty && newPlaylists.isEmpty) {
      await LocalStore.clearHeld();

      return (0, null);
    }

    // On top, as Save from Search puts a station, and in the order they had
    // on the device: just copied, they are the ones the listener looks for.

    _stations = [...added, ..._stations];
    _playlists = [..._playlists, ...newPlaylists];

    // Kept until the Pod has them: a failed write must leave them to retry.

    final error = await _commit();
    if (error == null) await LocalStore.clearHeld();

    return (added.length, error);
  }

  /// How many device-held stations are not yet on the Pod.
  ///
  /// Drives whether Settings bothers offering [copyLocalToPod] at all.

  Future<int> localOnlyCount() async {
    if (_testMode || _source != LibrarySource.pod) return 0;
    final (localStations, _) = await LocalStore.loadHeld();
    final urls = {for (final s in _stations) s.url};

    return localStations.where((s) => !urls.contains(s.url)).length;
  }

  /// Load a library directly, bypassing both stores. Used by tests.

  void loadForTest(
    List<Station> stations,
    List<Playlist> playlists, {
    LibrarySource source = LibrarySource.local,
  }) {
    _testMode = true;
    _source = source;
    _stations = stations;
    _playlists = playlists;
    _loading = false;
    notifyListeners();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Publish a change: tell the UI, then the media session, then the store.

  /// For the podcast part, whose extension cannot call the protected
  /// [notifyListeners] itself.

  void _notify() => notifyListeners();

  Future<String?> _commit() async {
    notifyListeners();
    await _pushToPlayer();

    return saveAll();
  }

  /// Hand the library to the audio handler so the notification and the car
  /// see the change at once.
  ///
  /// Best-effort: in tests there is no media session at all, and a handler
  /// that cannot be reached must never block the save that follows.

  Future<void> _pushToPlayer() async {
    if (_testMode) return;
    try {
      // 20261005 gjw Materialise the user-chosen icons BEFORE the browse
      // tree is rebuilt. Station.icon is base64, which a head unit cannot
      // fetch; StationIconCache writes each one out so browse_tree can hand
      // over a file:// artUri. Synchronous lookup afterwards, because
      // stationMediaItem is a pure function called from the audio handler
      // and the CarPlay bridge alike.

      await StationIconCache.sync(_stations);

      Player.handler.setLibrary(_stations, _playlists);
    } catch (e) {
      debugPrint('[AppProvider] player sync error: $e');
    }
  }

  /// Stable content signature for change detection.

  String _signature() => [
    for (final s in _stations)
      '${s.id}:${s.name}:${s.url}:${CastStore.of(s.id).length}',
    for (final p in _playlists) '${p.id}:${p.name}:${p.stationIds.join('|')}',
  ].join(',');

  static List<T> _decode<T>(
    String? json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (json == null || json.isEmpty) return [];

    return (jsonDecode(json) as List)
        .cast<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
  }
}
