/// ViewPrefs — device-local view preferences.
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
