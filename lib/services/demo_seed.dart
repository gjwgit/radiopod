/// DemoSeed — remembers that the starter stations have been offered.
///
// Time-stamp: <Wednesday 2026-10-08 09:00:00 +1100 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0
//
/// Authors: Graham Williams

library;

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Whether the demo stations have already been put into a library.
///
/// 20261008 gjw ONCE, NOT WHENEVER THE LIST IS EMPTY. "Empty" is also what
/// someone who has just deleted their last station sees, and having three
/// stations they did not ask for reappear on the next start-up would be a
/// bug, not a welcome. So the seeding is remembered, and an empty library
/// stays empty once the user has made it so.
///
/// A DEVICE preference, like the sleep timer's length. Writing it to the Pod
/// would mean an encrypted round trip to record a boolean, and it is of no
/// interest to another device: a second device with its own empty library
/// wants the same starting point.

class DemoSeed {
  DemoSeed._();

  static const _key = 'demo_stations_seeded';

  /// Whether seeding has already happened on this device.
  ///
  /// An unreadable preference counts as ALREADY SEEDED. Getting this wrong
  /// in that direction costs an empty Stations list, which the empty state
  /// already explains; the other way would add three stations on every
  /// start-up, over and over, which is far worse.

  static Future<bool> get done async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getBool(_key) ?? false;
    } on Object catch (e) {
      debugPrint('[DemoSeed] could not read: $e');

      return true;
    }
  }

  /// Record that the starter stations have been added.

  static Future<void> markDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } on Object catch (e) {
      debugPrint('[DemoSeed] could not write: $e');
    }
  }

  /// Forget, so the next empty start-up seeds again. For tests.

  @visibleForTesting
  static Future<void> resetForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
