/// LibraryCache — a device-local copy of the station library.
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

import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';

/// The last loaded library, kept on the device so the car can browse it.
///
/// WHY THIS EXISTS. Android Auto starts the media service on its own, often
/// before the user has opened the app, and it will not wait while a Solid
/// login and a security-key unlock complete — the browse tree must be there
/// the moment the head unit asks. So the station names and stream URLs are
/// mirrored here and handed straight to the audio handler at startup.
///
/// PRIVACY. This is a real trade-off and worth being clear about. The copy on
/// the Pod is encrypted; this one is plain JSON in the app's private
/// SharedPreferences, readable by anything with access to the unlocked
/// device. It holds only what a playlist file holds — station names and
/// stream URLs — never the security key, the WebID or any credential, and it
/// never leaves the device. Settings offers a Clear button, and clearing it
/// costs nothing but the car's ability to browse before the app is opened.

class LibraryCache {
  LibraryCache._();

  static const _stationsKey = 'cached_stations';
  static const _playlistsKey = 'cached_playlists';

  /// Mirror the library to the device. Failures are logged, never thrown —
  /// a cache that cannot be written must not break a Pod save.

  static Future<void> save(
    List<Station> stations,
    List<Playlist> playlists,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _stationsKey,
        jsonEncode([for (final s in stations) s.toJson()]),
      );
      await prefs.setString(
        _playlistsKey,
        jsonEncode([for (final p in playlists) p.toJson()]),
      );
    } catch (e) {
      debugPrint('[LibraryCache] save error: $e');
    }
  }

  /// Read the mirrored library, or two empty lists if there is none.

  static Future<(List<Station>, List<Playlist>)> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return (
        _decode(prefs.getString(_stationsKey), Station.fromJson),
        _decode(prefs.getString(_playlistsKey), Playlist.fromJson),
      );
    } catch (e) {
      debugPrint('[LibraryCache] load error: $e');

      return (<Station>[], <Playlist>[]);
    }
  }

  /// Forget the mirrored library.

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stationsKey);
    await prefs.remove(_playlistsKey);
  }

  /// Decode a stored JSON array, treating anything unparseable as empty.
  ///
  /// A cache written by an older version of the app is not worth a crash at
  /// startup — it is rebuilt on the next load from the Pod.

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
      debugPrint('[LibraryCache] discarding unreadable cache: $e');

      return [];
    }
  }
}
