/// Cast text — dates, lengths and progress in words.
///
// Time-stamp: <Friday 2026-10-16 06:00:00 +1100 Graham Williams>
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

import 'package:radiopod/models/cast.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `16 Oct 2026`, in the device's local time.

String castDate(DateTime d) {
  final l = d.toLocal();

  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

/// `45 s`, `29 min`, `1 h 4 min`. Rounded to the minute above a minute.

String castLength(Duration d) {
  if (d < const Duration(minutes: 1)) return '${d.inSeconds} s';
  final minutes = (d.inSeconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final m = minutes % 60;

  return m == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h $m min';
}

/// The one line about a cast under its title: when, how long, and how far
/// the listener has got.

String castSummary(Cast c) {
  final remaining = c.remaining;

  return [
    castDate(c.published),
    if (c.duration != null) castLength(c.duration!),
    if (c.disabled)
      'Switched off'
    else if (c.played)
      'Played'
    else if (c.position > Duration.zero)
      remaining == null
          ? '${castLength(c.position)} in'
          : '${castLength(remaining)} left',
  ].join(' · ');
}
