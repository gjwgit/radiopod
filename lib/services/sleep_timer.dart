/// SleepTimer — stop playback after a set time.
///
// Time-stamp: <Tuesday 2026-10-06 19:00:00 +1100 Graham Williams>
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

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:radiopod/constants/app.dart';

/// Stops playback once, at a time the listener chose.
///
/// 20261006 gjw Lives beside the PLAYER, not inside a screen. Someone who
/// sets a sleep timer puts the phone down, and the screen it was set from is
/// disposed long before the timer fires. The media service keeps the process
/// alive while a station plays, so a plain Timer is enough — no alarm, no
/// wake lock of its own, nothing to ask the user's permission for.
///
/// It does ONE thing when it fires: calls the callback it was given, which
/// is the handler's stop(). It does not pause, fade, or close the app.
///
/// AN ELAPSED TIMER IS NOT A STOPPED PLAYER. The two are deliberately kept
/// apart: starting another station does not cancel the timer, because "stop
/// playing at bedtime" is about the clock and not about which station is on.
/// Only the listener cancels it, or its own firing.

class SleepTimer {
  SleepTimer(this._onExpire);

  /// What to do when the time is up. Called once, after which the timer is
  /// no longer running.

  final Future<void> Function() _onExpire;

  Timer? _ticker;
  DateTime? _endsAt;

  /// How long [toggle] runs for, as chosen in Settings.
  ///
  /// Held here rather than read from storage at the moment of use, so that
  /// turning the timer on is instant and cannot fail. Player.init loads the
  /// stored value into this, and the Settings section writes both.

  Duration defaultDuration = sleepTimerDefault;

  /// Turn the timer on for [defaultDuration], or off if it is already on.
  ///
  /// 20261006 gjw The app bar icon is a plain ON/OFF switch — one tap, no
  /// sheet, no picker. Choosing HOW LONG is a setting made once and left
  /// alone; deciding to sleep is the thing done nightly, and it should cost
  /// a single tap. Returns true when a timer was started.

  bool toggle() {
    if (isRunning) {
      cancel();

      return false;
    }

    start(defaultDuration);

    return isRunning;
  }

  /// Whole minutes left, rounded UP, or null when no timer is set.
  ///
  /// ROUNDED UP AND IN MINUTES ON PURPOSE. A countdown that reads "0 minutes"
  /// for the last fifty-nine seconds looks stopped when it is not, and this
  /// notifies only when the displayed number changes, so the app bar rebuilds
  /// once a minute rather than once a second.

  final ValueNotifier<int?> minutesLeft = ValueNotifier<int?>(null);

  /// Whether a timer is counting down.

  bool get isRunning => _endsAt != null;

  /// Exactly how long is left, for a caller that wants more than minutes.

  Duration? get remaining {
    final endsAt = _endsAt;
    if (endsAt == null) return null;
    final left = endsAt.difference(_now());

    return left.isNegative ? Duration.zero : left;
  }

  /// Start counting down [duration], replacing any timer already set.
  ///
  /// A duration of zero or less cancels instead of firing immediately, so a
  /// stray value can never silence a station the moment it is chosen.

  void start(Duration duration) {
    cancel();
    if (duration <= Duration.zero) return;

    _endsAt = _now().add(duration);
    _publish();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining == Duration.zero) {
        _fire();
      } else {
        _publish();
      }
    });
  }

  /// Stop counting down. Playback is untouched.

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    _publish();
  }

  /// Time is up: stop the timer FIRST, then stop playback.
  ///
  /// In that order so a stop that throws still leaves the timer finished.
  /// Otherwise a failing stop would be retried every second for ever.

  void _fire() {
    cancel();
    unawaited(
      _onExpire().catchError((Object e) {
        debugPrint('[SleepTimer] could not stop playback: $e');
      }),
    );
  }

  void _publish() {
    final left = remaining;
    minutesLeft.value = left == null ? null : (left.inSeconds / 60).ceil();
  }

  /// The clock, as a seam for tests. Production always uses the real one.

  @visibleForTesting
  static DateTime Function() nowForTest = DateTime.now;

  static DateTime _now() => nowForTest();

  void dispose() {
    cancel();
    minutesLeft.dispose();
  }
}
