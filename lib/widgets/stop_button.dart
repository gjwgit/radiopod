/// StopButton — stop whatever station is on air.
///
// Time-stamp: <Tuesday 2026-10-13 10:00:00 +1100 Graham Williams>
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

import 'package:flutter/material.dart';

import 'package:markdown_tooltip/markdown_tooltip.dart';

/// A Stop button that becomes Play once stopped, so the same tap brings the
/// station back.
///
/// 20261013 gjw Tapping the station on air already stops it, but nothing
/// on screen says so. A plain button beside the filter box is the obvious
/// place to look. Kept a plain widget, like StationTile, so it can be
/// tested without a running media session — the caller supplies [active].
///
/// Disabled only before anything has been played, when there is no station
/// to start again: [onStart] is then null.

class StopButton extends StatelessWidget {
  const StopButton({
    super.key,
    required this.active,
    required this.onStop,
    this.onStart,
    this.stationName,
  });

  /// Whether a station is playing, connecting, buffering or paused.

  final bool active;

  final VoidCallback onStop;

  /// Start the last station again, or null when there is none.

  final VoidCallback? onStart;

  /// The name of the station on air, when it is known. A station played
  /// from Search without being saved is not in the library to look up.

  final String? stationName;

  String get _station =>
      stationName == null ? 'the last station' : '*$stationName*';

  @override
  Widget build(BuildContext context) => MarkdownTooltip(
    message: active
        ? '''

    **Stop**

    Stop ${stationName == null ? 'the station on air' : '*$stationName*'}.
    Tap again to start it once more.

    '''
        : onStart != null
        ? '''

    **Play**

    Start $_station again, at the live edge of its stream.

    '''
        : '''

    **Stop**

    Nothing is playing. Tap a station in the list to start it.

    ''',
    child: IconButton.filledTonal(
      icon: Icon(active || onStart == null ? Icons.stop : Icons.play_arrow),
      onPressed: active ? onStop : onStart,
    ),
  );
}
