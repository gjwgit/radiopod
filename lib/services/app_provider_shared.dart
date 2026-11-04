/// AppProvider — playlists other Solid users have shared with this user.
///
// Time-stamp: <Monday 2026-11-02 12:00:00 +1100 Tony Chen>
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
/// Authors: Tony Chen

part of 'app_provider.dart';

/// Taking in the playlists shared with this user.
///
/// A playlist shared from RadioPod is its own file on the owner's Pod,
/// holding the stations themselves (see [PlaylistLibrary.saveSharedPlaylist]).
/// Granting access records the share in the recipient's permission log, which
/// is what [syncSharedPlaylists] reads, much as NotePod lists the notes shared
/// with its user.
///
/// A shared playlist becomes an ordinary playlist in the recipient's library,
/// so it is in the car, in exports and on the Playlists screen like any other.
/// Its stations join the library too, matched by stream address so a station
/// the recipient already has is not added twice. The playlist keeps a link to
/// the owner's copy, and each load refreshes its stations from that copy, so
/// it follows the owner as the owner shares it again after a change.

extension SharedPlaylists on AppProvider {
  /// Bring in new shares, refresh those already taken in, and remove those
  /// whose access has been revoked. Stations stay in the library either way:
  /// once added they are the recipient's own.
  ///
  /// A share the recipient has deleted stays deleted. [sharedPlaylistsFileName]
  /// remembers which grant each share was last taken in from, and a deleted
  /// playlist comes back only with a newer grant, when the owner shares it
  /// again.
  ///
  /// Best-effort throughout: a missing permission log (nothing has ever been
  /// shared) or an owner's Pod that does not answer leaves the library as it
  /// is rather than reporting an error the user can do nothing about.

  Future<void> syncSharedPlaylists() async {
    if (_testMode || _source != LibrarySource.pod) return;

    final Map<dynamic, dynamic> shares;
    try {
      final result = await sharedResources();
      if (result is! Map) return;
      shares = result;
    } catch (e) {
      debugPrint('[AppProvider] no shared playlists read: $e');

      return;
    }

    final seen = decodeSeenShares(
      await PodService.load(sharedPlaylistsFileName),
    );
    var seenChanged = false;
    var libraryChanged = false;

    for (final MapEntry(key: key, value: value) in shares.entries) {
      final url = key.toString();
      if (!isSharedPlaylistUrl(url) || value is! Map) continue;

      final grantedAt = value[PermissionLogLiteral.logtime]?.toString() ?? '';
      final owner = value[PermissionLogLiteral.owner]?.toString();
      final taken = _playlists.any((p) => p.sharedFrom == url);

      if (value[PermissionLogLiteral.type]?.toString() == 'revoke') {
        if (taken) {
          _playlists = _playlists.where((p) => p.sharedFrom != url).toList();
          libraryChanged = true;
        }
        continue;
      }

      // Taken in from this very grant and deleted since.

      if (!taken && seen[url] == grantedAt) continue;

      final json = await PodService.loadExternal(url);
      final shared = json == null ? null : decodeSharedPlaylist(json);
      if (shared == null) continue;

      if (takeInShared(url, owner, grantedAt, shared)) libraryChanged = true;
      if (seen[url] != grantedAt) {
        seen[url] = grantedAt;
        seenChanged = true;
      }
    }

    if (seenChanged) {
      await PodService.save(sharedPlaylistsFileName, jsonEncode(seen));
    }
    if (libraryChanged) await _commit();
  }

  /// Add or refresh the playlist shared from [url], returning whether the
  /// library changed. Neither saves nor notifies; the caller commits.

  @visibleForTesting
  bool takeInShared(
    String url,
    String? owner,
    String grantedAt,
    ({String name, List<Station> stations}) shared,
  ) {
    final byUrl = {for (final s in _stations) s.url: s};
    final added = <Station>[];
    final ids = <String>[];

    for (final s in shared.stations) {
      final existing = byUrl[s.url];
      if (existing != null) {
        if (!ids.contains(existing.id)) ids.add(existing.id);
        continue;
      }

      // A fresh id: the owner's ids belong to the owner's library and could
      // in principle collide with one already in this library.

      final copy = s.copyWith(id: _uuid.v4());
      byUrl[s.url] = copy;
      added.add(copy);
      ids.add(copy.id);
    }

    final index = _playlists.indexWhere((p) => p.sharedFrom == url);
    if (index == -1) {
      _playlists = [
        ..._playlists,
        Playlist(
          id: _uuid.v4(),
          name: shared.name,
          stationIds: ids,
          sharedFrom: url,
          sharedBy: owner,
          sharedAt: grantedAt,
        ),
      ];
    } else {
      // The name is left alone: the recipient may have renamed it.

      final current = _playlists[index];
      if (added.isEmpty &&
          current.sharedAt == grantedAt &&
          listEquals(current.stationIds, ids)) {
        return false;
      }
      _playlists = [
        for (final p in _playlists)
          p.sharedFrom == url
              ? p.copyWith(stationIds: ids, sharedAt: grantedAt)
              : p,
      ];
    }

    // On top, as copyLocalToPod puts new stations: just received, they are
    // the ones the listener goes looking for.

    _stations = [...added, ..._stations];

    return true;
  }
}

/// True when [url] names a playlist shared from RadioPod, rather than some
/// other file in the same permission log.

@visibleForTesting
bool isSharedPlaylistUrl(String url) {
  final name = url.split('/').last;

  return name.startsWith(sharedPlaylistFilePrefix) && name.endsWith('.ttl');
}

/// Read the JSON written by [PlaylistLibrary.saveSharedPlaylist], or null when
/// it is not a shared playlist this version understands.

@visibleForTesting
({String name, List<Station> stations})? decodeSharedPlaylist(String json) {
  try {
    final j = jsonDecode(json);
    if (j is! Map<String, dynamic>) return null;

    return (
      name: j['name'] as String,
      stations: [
        for (final s in (j['stations'] as List? ?? const []))
          Station.fromJson(s as Map<String, dynamic>),
      ],
    );
  } catch (e) {
    debugPrint('[AppProvider] unreadable shared playlist: $e');

    return null;
  }
}

/// Read the record of which grant each share was last taken in from, keyed
/// by the shared file's URL. Empty when there is none yet.

@visibleForTesting
Map<String, String> decodeSeenShares(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final j = jsonDecode(json);

    return j is Map
        ? {for (final e in j.entries) e.key.toString(): e.value.toString()}
        : {};
  } catch (_) {
    return {};
  }
}
