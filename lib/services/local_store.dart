/// LocalStore — the station library held on this device.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
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

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';

/// The station library as kept on this device, in SharedPreferences.
///
/// It has TWO jobs, which is why it is always written even when a Pod is in
/// use.
///
/// 1. WHEN LOGGED OUT it is the library. Tapping Continue at the login screen
///    gives a working radio app with no Solid account at all: stations saved,
///    playlists built, M3U files imported, all of it kept here and still here
///    next launch. Nothing is sent anywhere.
///
/// 2. WHEN LOGGED IN the Pod is the library and this is a mirror of it, kept
///    for Android Auto. The car starts the media service on its own, often
///    before the app has been opened, and will not wait while a login and a
///    security-key unlock complete — the browse tree has to be there the
///    moment the head unit asks.
///
/// PRIVACY. Worth being plain about. A Pod copy is encrypted; this one is
/// plain JSON in the app's private storage, readable by anything with access
/// to the unlocked device. It holds only what a playlist file holds —
/// station names and stream URLs — never the security key, the WebID or any
/// credential, and it never leaves the device. Settings offers a Clear
/// button; when logged in that costs only the car's ability to browse before
/// the app is opened, but when logged OUT it is the library itself, so the
/// button warns accordingly.
///
/// 20261015 gjw THE MIRROR MUST NOT EAT THE LIBRARY. Both jobs share one
/// pair of keys, so the first Pod load after a login used to write the Pod's
/// stations straight over the ones saved while logged out, before Copy to
/// Pod could see them; they were simply gone. Each save now records where
/// the copy came from, and a Pod copy about to replace a device-built one
/// first moves it aside as the HELD library, which Copy to Pod reads.

class LocalStore {
  LocalStore._();

  // 20260921 gjw The keys keep their original `cached_` names so that a
  // library built by an earlier build is still found after the class was
  // renamed from LibraryCache. Renaming them would silently orphan it.

  static const _stationsKey = 'cached_stations';
  static const _playlistsKey = 'cached_playlists';

  /// Where the copy under [_stationsKey] came from: [_fromPod], or anything
  /// else for a library built on this device. A copy from before this key
  /// existed has none and counts as device-built, the cautious reading.

  static const _originKey = 'cached_origin';
  static const _fromPod = 'pod';

  /// The device-built library set aside when a Pod copy replaced it.

  static const _heldStationsKey = 'held_stations';
  static const _heldPlaylistsKey = 'held_playlists';

  /// Write the library to the device. Failures are logged, never thrown —
  /// when a Pod is also in use, a local write that fails must not break the
  /// Pod save that follows it.
  ///
  /// [fromPod] marks a mirror of the Pod. Writing one over a device-built
  /// library holds that library first, see [loadHeld].

  static Future<void> save(
    List<Station> stations,
    List<Playlist> playlists, {
    required bool fromPod,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (fromPod && prefs.getString(_originKey) != _fromPod) {
        await _hold(prefs);
      }
      await prefs.setString(_originKey, fromPod ? _fromPod : 'device');
      await prefs.setString(
        _stationsKey,
        jsonEncode([for (final s in stations) s.toJson()]),
      );
      await prefs.setString(
        _playlistsKey,
        jsonEncode([for (final p in playlists) p.toJson()]),
      );
    } catch (e) {
      debugPrint('[LocalStore] save error: $e');
    }
  }

  /// Read the library, or two empty lists when there is none.

  static Future<(List<Station>, List<Playlist>)> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return (
        _decode(prefs.getString(_stationsKey), Station.fromJson),
        _decode(prefs.getString(_playlistsKey), Playlist.fromJson),
      );
    } catch (e) {
      debugPrint('[LocalStore] load error: $e');

      return (<Station>[], <Playlist>[]);
    }
  }

  /// The library held back from the Pod, or two empty lists.
  ///
  /// What Copy to Pod offers: everything saved on this device while logged
  /// out, as it stood when a Pod copy replaced it.

  static Future<(List<Station>, List<Playlist>)> loadHeld() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return (
        _decode(prefs.getString(_heldStationsKey), Station.fromJson),
        _decode(prefs.getString(_heldPlaylistsKey), Playlist.fromJson),
      );
    } catch (e) {
      debugPrint('[LocalStore] held load error: $e');

      return (<Station>[], <Playlist>[]);
    }
  }

  /// Forget the held library, once it has been copied to the Pod.

  static Future<void> clearHeld() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_heldStationsKey);
    await prefs.remove(_heldPlaylistsKey);
  }

  /// Forget the device copy, and anything held back with it.

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stationsKey);
    await prefs.remove(_playlistsKey);
    await prefs.remove(_originKey);
    await clearHeld();
  }

  /// Add the device-built library to the held one, by stream URL for
  /// stations and by name for playlists, so logging in twice without a copy
  /// in between loses nothing and duplicates nothing.

  static Future<void> _hold(SharedPreferences prefs) async {
    final (stations, playlists) = (
      _decode(prefs.getString(_stationsKey), Station.fromJson),
      _decode(prefs.getString(_playlistsKey), Playlist.fromJson),
    );
    if (stations.isEmpty && playlists.isEmpty) return;

    final (heldStations, heldPlaylists) = (
      _decode(prefs.getString(_heldStationsKey), Station.fromJson),
      _decode(prefs.getString(_heldPlaylistsKey), Playlist.fromJson),
    );
    final urls = {for (final s in heldStations) s.url};
    final names = {for (final p in heldPlaylists) p.name};

    await prefs.setString(
      _heldStationsKey,
      jsonEncode([
        ...heldStations.map((s) => s.toJson()),
        for (final s in stations)
          if (urls.add(s.url)) s.toJson(),
      ]),
    );
    await prefs.setString(
      _heldPlaylistsKey,
      jsonEncode([
        ...heldPlaylists.map((p) => p.toJson()),
        for (final p in playlists)
          if (names.add(p.name)) p.toJson(),
      ]),
    );
  }

  /// Decode a stored JSON array, treating anything unparseable as empty.
  ///
  /// Data written by an older version of the app is not worth a crash at
  /// startup. When logged in it is rebuilt from the Pod on the next load;
  /// when logged out this does lose the library, which is the price of not
  /// refusing to start.

  static List<T> _decode<T>(
    String? json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (json == null || json.isEmpty) return [];
    try {
      return (jsonDecode(json) as List)
          .cast<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    } catch (e) {
      debugPrint('[LocalStore] discarding unreadable data: $e');

      return [];
    }
  }
}
