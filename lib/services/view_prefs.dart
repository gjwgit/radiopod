/// ViewPrefs — device-local view preferences.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:shared_preferences/shared_preferences.dart';

/// Per-device display choices, remembered between sessions.
///
/// Deliberately SharedPreferences ONLY. These are device preferences, never
/// written to the Pod, so a stale Pod copy cannot overwrite them on login.
/// Every read takes an explicit default, so a missing key is not an error.

class ViewPrefs {
  ViewPrefs._();

  /// Stations screen: the id of the playlist being shown, or empty for all.

  static const stationsFilterPlaylist = 'stations_filter_playlist';

  /// Search screen: whether the last search matched on genre rather than
  /// name, so the segmented control comes back where it was left.

  static const searchByGenre = 'search_by_genre';

  static Future<bool> getBool(String key, {required bool orElse}) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(key) ?? orElse;
  }

  static Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<String> getString(String key, {required String orElse}) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(key) ?? orElse;
  }

  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
