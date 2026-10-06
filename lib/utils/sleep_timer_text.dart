/// Wording for the sleep timer.
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

/// A duration as a choice reads it: "30 minutes", "1 hour", "1½ hours".
///
/// Pure functions with their own tests, like m3u.dart and pls.dart, because
/// the wording is the whole of what these do and it is easy to get subtly
/// wrong — "1 hours", "90 minutes" where "1½ hours" was meant.

String sleepTimerLabel(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 60) return _minutes(minutes);

  final hours = minutes ~/ 60;
  final rest = minutes % 60;

  // A half hour stays PLURAL — "1½ hours", never "1½ hour" — because it is
  // more than one. Only a whole single hour is singular.

  if (rest == 30) return '$hours½ hours';

  final unit = hours == 1 ? 'hour' : 'hours';
  if (rest == 0) return '$hours $unit';

  return '$hours $unit ${_minutes(rest)}';
}

String _minutes(int n) => n == 1 ? '1 minute' : '$n minutes';

/// How long is left, as a sentence ending: "in 24 minutes", "very soon".
///
/// Takes the exact remaining time and rounds UP to whole minutes, matching
/// SleepTimer.minutesLeft, so the sheet and the app bar never disagree by a
/// minute while both are on screen.
///
/// The last minute reads "very soon" rather than "in 1 minute". The number
/// would be stale before it was read, and the only thing worth saying at
/// that point is that it is about to happen.

String sleepTimerSummary(Duration? remaining) {
  if (remaining == null) return 'when you stop it';

  final minutes = (remaining.inSeconds / 60).ceil();
  if (minutes <= 1) return 'very soon';

  return 'in ${sleepTimerLabel(Duration(minutes: minutes))}';
}
