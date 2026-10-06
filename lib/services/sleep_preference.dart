/// SleepPreference — how long the sleep timer runs, kept on this device.
///
// Time-stamp: <Tuesday 2026-10-06 20:00:00 +1100 Graham Williams>
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

import 'package:radiopod/constants/app.dart';

/// The sleep timer's length, as chosen in Settings.
///
/// 20261006 gjw A DEVICE SETTING, not Pod data. It says nothing about the
/// user and nothing about what they listen to — it is of a kind with the
/// window size and the theme, which solidui also keeps locally. Writing it
/// to the Pod would mean an encrypted round trip to store the number 30.
///
/// Stored as minutes rather than as a Duration so the value in
/// SharedPreferences stays readable and survives any change to how durations
/// are represented.

class SleepPreference {
  SleepPreference._();

  static const _key = 'sleep_timer_minutes';

  /// The stored length, or [sleepTimerDefault] when there is none.
  ///
  /// A stored value that is no longer one of [sleepTimerChoices] falls back
  /// to the default rather than being honoured: the choices are what Settings
  /// can show, and a timer the user cannot see or change in the UI would be
  /// worse than one they can.

  static Future<Duration> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final minutes = prefs.getInt(_key);
      if (minutes == null) return sleepTimerDefault;

      final stored = Duration(minutes: minutes);

      return sleepTimerChoices.contains(stored) ? stored : sleepTimerDefault;
    } on Object catch (e) {
      debugPrint('[SleepPreference] could not read: $e');

      return sleepTimerDefault;
    }
  }

  /// Remember [duration] as the length to use next time.

  static Future<void> save(Duration duration) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, duration.inMinutes);
    } on Object catch (e) {
      debugPrint('[SleepPreference] could not write: $e');
    }
  }
}
