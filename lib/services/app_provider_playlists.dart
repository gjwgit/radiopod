/// AppProvider's playlists — grouping, renaming and ordering them.
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

/// Playlist operations on the library.
///
/// 20261016 gjw A part of AppProvider, as [PodcastLibrary] is, so every
/// change still goes through `_commit()` (CLAUDE.md §5) while
/// app_provider.dart stays under the line limit. Playlists hold station
/// ids, never copies; see CLAUDE.md §5.

extension PlaylistLibrary on AppProvider {
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

  /// Move a playlist within the list of playlists.
  ///
  /// 20261005 gjw Distinct from [reorderInPlaylist], which orders the
  /// stations INSIDE one. This is the order the playlists themselves appear
  /// in — on the Playlists screen, and as the folders the driver scrolls
  /// past in the car before reaching All Stations. Putting the one used
  /// every morning at the top is the point.
  ///
  /// [newIndex] comes from `onReorderItem` and is already adjusted for the
  /// removed item, as in [reorderStation].

  Future<String?> reorderPlaylist(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return Future.value();
    if (oldIndex < 0 || oldIndex >= _playlists.length) return Future.value();

    final list = List<Playlist>.from(_playlists);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), moved);
    _playlists = list;

    return _commit();
  }

  /// Move a station within [playlistId].
  ///
  /// 20261005 gjw The order inside a playlist is the user's order too, for
  /// the same reasons the library's is (see [reorderStation]): it is what the
  /// car's folder lists and what Next and Previous walk through, so dragging
  /// a station to the top of a playlist puts it first in the car.
  ///
  /// INDICES ARE POSITIONS IN THE VISIBLE LIST, not in `stationIds`. The two
  /// differ when a playlist still names a station the library no longer has —
  /// [stationsOf] skips those, so the rows the user drags are only the live
  /// ones. Reordering the live ids and appending any dangling ones keeps the
  /// visible result exactly what was dragged. Deleting a station already
  /// strips its id from every playlist, so a dangling id is a repair for
  /// something that should not happen rather than an ordinary case.
  ///
  /// [newIndex] comes from `onReorderItem` and has already been adjusted for
  /// the removed item. Do not subtract one; do not switch to `onReorder`.

  Future<String?> reorderInPlaylist(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) return Future.value();

    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return Future.value();

    final playlist = _playlists[index];
    final known = {for (final s in _stations) s.id};

    final live = [
      for (final id in playlist.stationIds)
        if (known.contains(id)) id,
    ];
    final dangling = [
      for (final id in playlist.stationIds)
        if (!known.contains(id)) id,
    ];

    if (oldIndex < 0 || oldIndex >= live.length) return Future.value();

    final moved = live.removeAt(oldIndex);
    live.insert(newIndex.clamp(0, live.length), moved);

    _playlists = [
      for (final p in _playlists)
        if (p.id == playlistId)
          p.copyWith(stationIds: [...live, ...dangling])
        else
          p,
    ];

    return _commit();
  }
}
