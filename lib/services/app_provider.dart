/// AppProvider — state management for the RadioPod station library.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:solidpod/solidpod.dart' show isUserLoggedIn;
import 'package:uuid/uuid.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/local_store.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/services/pod_service.dart';
import 'package:radiopod/utils/playlist_file.dart';

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
  /// Matching on URL rather than name is what stops the same station being
  /// saved twice from two different Radio-Browser entries, which is common
  /// for popular stations.

  Future<String?> addStation(Station station) {
    if (_stations.any((s) => s.url == station.url)) return Future.value();
    _stations = [..._stations, station];

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

  // ── Playlists ─────────────────────────────────────────────────────────────

  Future<String?> addPlaylist(String name, {List<String>? stationIds}) {
    _playlists = [
      ..._playlists,
      Playlist(id: _uuid.v4(), name: name, stationIds: stationIds ?? const []),
    ];

    return _commit();
  }

  Future<String?> renamePlaylist(String id, String name) {
    _playlists = [
      for (final p in _playlists) p.id == id ? p.copyWith(name: name) : p,
    ];

    return _commit();
  }

  /// Delete a playlist. The stations themselves stay in the library — a
  /// playlist is a view over the library, not an owner of it.

  Future<String?> deletePlaylist(String id) {
    _playlists = _playlists.where((p) => p.id != id).toList();

    return _commit();
  }

  /// Add [stationId] to [playlistId], ignoring a station already in it.

  Future<String?> addToPlaylist(String playlistId, String stationId) {
    _playlists = [
      for (final p in _playlists)
        if (p.id == playlistId && !p.stationIds.contains(stationId))
          p.copyWith(stationIds: [...p.stationIds, stationId])
        else
          p,
    ];

    return _commit();
  }

  Future<String?> removeFromPlaylist(String playlistId, String stationId) {
    _playlists = [
      for (final p in _playlists)
        if (p.id == playlistId)
          p.copyWith(
            stationIds: p.stationIds.where((i) => i != stationId).toList(),
          )
        else
          p,
    ];

    return _commit();
  }

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

  Future<void> play(Station station, {List<Station>? queue}) =>
      Player.handler.playStation(station, queue: queue);

  // ── Loading and saving ────────────────────────────────────────────────────

  /// Ask solidpod whether there is a login, and set [source] from the answer.
  ///
  /// Called before every load rather than cached, because the answer changes
  /// while the app is running: the user can log in from the profile menu
  /// long after tapping Continue, and can log out again.

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
      if (await resolveSource() == LibrarySource.pod) {
        _stations = _decode(
          await PodService.load(stationsFileName),
          Station.fromJson,
        );
        _playlists = _decode(
          await PodService.load(playlistsFileName),
          Playlist.fromJson,
        );

        // Refresh the device mirror so the car can browse the Pod library
        // before the next login completes.

        await LocalStore.save(_stations, _playlists);
      } else {
        final (stations, playlists) = await LocalStore.load();
        _stations = stations;
        _playlists = playlists;
      }
      await _pushToPlayer();
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

    await LocalStore.save(_stations, _playlists);
    if (_source == LibrarySource.local) return null;

    final stationsErr = await PodService.save(
      stationsFileName,
      jsonEncode([for (final s in _stations) s.toJson()]),
    );
    final playlistsErr = await PodService.save(
      playlistsFileName,
      jsonEncode([for (final p in _playlists) p.toJson()]),
    );
    final err = stationsErr ?? playlistsErr;
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

    final (localStations, localPlaylists) = await LocalStore.load();
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

    if (added.isEmpty && newPlaylists.isEmpty) return (0, null);

    _stations = [..._stations, ...added];
    _playlists = [..._playlists, ...newPlaylists];

    return (added.length, await _commit());
  }

  /// How many device-held stations are not yet on the Pod.
  ///
  /// Drives whether Settings bothers offering [copyLocalToPod] at all.

  Future<int> localOnlyCount() async {
    if (_testMode || _source != LibrarySource.pod) return 0;
    final (localStations, _) = await LocalStore.load();
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
      Player.handler.setLibrary(_stations, _playlists);
    } catch (e) {
      debugPrint('[AppProvider] player sync error: $e');
    }
  }

  /// Stable content signature for change detection.

  String _signature() => [
    for (final s in _stations) '${s.id}:${s.name}:${s.url}',
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
