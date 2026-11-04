/// Playlist — a named, ordered group of stations.
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

/// A named list of stations, held as station ids rather than copies.
///
/// Stations live once in the library and are referenced from any number of
/// playlists, so renaming or re-tagging a station updates every playlist it
/// appears in. The order of [stationIds] is the play order and is what an
/// M3U or PLS export writes out.

class Playlist {
  final String id;
  final String name;
  final List<String> stationIds;

  /// For a playlist someone else shared: the URL of the owner's shared copy
  /// on their Pod. Null for the user's own playlists.
  ///
  /// The link is what lets a later load refresh the stations from the
  /// owner's copy rather than import the same playlist a second time.

  final String? sharedFrom;

  /// The WebID of the owner who shared it, shown under the playlist's name.

  final String? sharedBy;

  /// When the owner shared it, as their permission log records the grant.

  final String? sharedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.stationIds = const [],
    this.sharedFrom,
    this.sharedBy,
    this.sharedAt,
  });

  /// True for a playlist shared with the user by someone else.

  bool get isShared => sharedFrom != null;

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'stationIds': stationIds,
    if (sharedFrom != null) 'sharedFrom': sharedFrom,
    if (sharedBy != null) 'sharedBy': sharedBy,
    if (sharedAt != null) 'sharedAt': sharedAt,
  };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
    id: j['id'] as String,
    name: j['name'] as String,
    stationIds: (j['stationIds'] as List?)?.cast<String>() ?? const [],
    sharedFrom: j['sharedFrom'] as String?,
    sharedBy: j['sharedBy'] as String?,
    sharedAt: j['sharedAt'] as String?,
  );

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? stationIds,
    String? sharedAt,
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    stationIds: stationIds ?? this.stationIds,
    sharedFrom: sharedFrom,
    sharedBy: sharedBy,
    sharedAt: sharedAt ?? this.sharedAt,
  );
}
