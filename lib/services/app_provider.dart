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

import 'package:uuid/uuid.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/library_cache.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/services/pod_service.dart';
import 'package:radiopod/utils/playlist_file.dart';

const _uuid = Uuid();

/// Phases of app startup, used to show phase-aware busy feedback while the
/// Pod is unlocked and the initial data is pulled.

enum StartupPhase { idle, unlocking, loading, ready }

/// App-level state: the station library, the playlists, and Pod sync.
///
/// Every mutation goes through [_commit], which notifies listeners, hands
/// the new library to the audio handler (so Android Auto and the
/// notification see it immediately) and writes it back to the Pod. That one
/// path is why a station added on the phone appears in the car without a
/// restart, and why nothing is ever saved locally but not remotely.

class AppProvider extends ChangeNotifier {
  List<Station> _stations = [];
  List<Playlist> _playlists = [];
  bool _loading = false;
  bool _isKeySaved = false;
  String? _error;
  StartupPhase _startupPhase = StartupPhase.idle;

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

  /// The library sorted by name, which is how the Stations screen lists it.

  List<Station> get stationsByName =>
      List<Station>.from(_stations)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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

  // ── Pod sync ──────────────────────────────────────────────────────────────

  Future<void> loadFromPod() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _stations = _decode(
        await PodService.load(stationsFileName),
        Station.fromJson,
      );
      _playlists = _decode(
        await PodService.load(playlistsFileName),
        Playlist.fromJson,
      );
      await _syncPlayer();
    } catch (e) {
      _error = 'Could not load your stations from the Pod.';
      debugPrint('[AppProvider] loadFromPod error: $e');
    } finally {
      // Always clear loading so the UI can't hang on the busy indicator.

      _loading = false;
      notifyListeners();
    }
  }

  /// Reload from the Pod and report whether anything actually changed, so
  /// the refresh button can say "already up to date" rather than nothing.

  Future<bool> refreshFromPod() async {
    if (_testMode) return false;
    final before = _signature();
    await loadFromPod();

    return _signature() != before;
  }

  /// Save both data files, returning the first error message or null.
  ///
  /// Both halves are always attempted, and the error is returned rather than
  /// swallowed, so an unawaited caller can hand the failure to solidui's
  /// SolidWriteFailures.

  Future<String?> saveAllToPod() async {
    if (_testMode) return null;
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

  /// Load a library directly, bypassing the Pod. Used by tests.

  void loadForTest(List<Station> stations, List<Playlist> playlists) {
    _testMode = true;
    _stations = stations;
    _playlists = playlists;
    _loading = false;
    notifyListeners();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Publish a change: tell the UI, then the media session, then the Pod.

  Future<String?> _commit() async {
    notifyListeners();
    await _syncPlayer();

    return saveAllToPod();
  }

  /// Hand the library to the audio handler and mirror it to the device.
  ///
  /// Both are best-effort. In tests there is no media session at all, and a
  /// failed local mirror must never block a Pod save.

  Future<void> _syncPlayer() async {
    if (_testMode) return;
    try {
      Player.handler.setLibrary(_stations, _playlists);
      await LibraryCache.save(_stations, _playlists);
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
