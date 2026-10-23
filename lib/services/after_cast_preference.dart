/// AfterCastPreference — what plays when a podcast episode finishes.
///
// Time-stamp: <Saturday 2026-10-24 10:00:00 +1100 Graham Williams>
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

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/utils/cast_merge.dart';

/// What plays when an episode finishes, as chosen in Settings.
///
/// 20261024 gjw A DEVICE SETTING, like SleepPreference: it says nothing
/// about the listener, and the car reads it with no Pod session. Stored as
/// the [AfterCast] name, so the value stays readable; a name no longer
/// known falls back to the default, [AfterCast.older].

class AfterCastPreference {
  AfterCastPreference._();

  static const _key = 'after_cast';

  static Future<AfterCast> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);

      return AfterCast.values.asNameMap()[name] ?? AfterCast.older;
    } on Object catch (e) {
      debugPrint('[AfterCastPreference] could not read: $e');

      return AfterCast.older;
    }
  }

  static Future<void> save(AfterCast choice) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, choice.name);
    } on Object catch (e) {
      debugPrint('[AfterCastPreference] could not write: $e');
    }
  }
}
