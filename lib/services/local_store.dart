/// LocalStore — the station library held on this device.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
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

class LocalStore {
  LocalStore._();

  // 20260921 gjw The keys keep their original `cached_` names so that a
  // library built by an earlier build is still found after the class was
  // renamed from LibraryCache. Renaming them would silently orphan it.

  static const _stationsKey = 'cached_stations';
  static const _playlistsKey = 'cached_playlists';

  /// Write the library to the device. Failures are logged, never thrown —
  /// when a Pod is also in use, a local write that fails must not break the
  /// Pod save that follows it.

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

  /// Forget the device copy.

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stationsKey);
    await prefs.remove(_playlistsKey);
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
