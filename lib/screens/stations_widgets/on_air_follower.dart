/// OnAirFollower — keep the highlighted station on air in view.
///
// Time-stamp: <Monday 2026-11-23 10:00:00 +1100 Graham Williams>
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

import 'package:material_ui/material_ui.dart';

/// Scrolls the Stations list so the row on air is on screen.
///
/// It scrolls only when there is something new to show: a different station
/// or podcast on air (Next from the car, the notification or the end of a
/// cast), playback starting (Play, even on the station already current), a
/// different filter, or a list freshly built (the page opened, or back from
/// the busy spinner). Between those the list is the listener's to
/// scroll, and a new song on the same station moves nothing. A row already in
/// view does not move at all; one out of view is brought just inside the
/// nearer edge.
///
/// The row is found through an [OnAirMarker] rather than a GlobalKey: a
/// reorderable list may build the dragged row twice, and a GlobalKey built
/// twice throws.

class OnAirFollower {
  /// The controller to give the list.

  final controller = ScrollController();

  /// What was last revealed: the station on air and the filter it was shown
  /// under, or null when nothing was.

  String? _shown;

  /// Whether playback was starting or under way at the last build.

  bool _wasActive = false;

  /// The context of the row on air, while it is built.

  BuildContext? _row;

  void dispose() => controller.dispose();

  /// Called as the list builds, with the row on air at [index] of [count]
  /// visible rows (-1 if none), whether playback is [active] (connecting,
  /// loading or playing), and the filter [query] in force.

  void follow({
    required String? stationId,
    required int index,
    required int count,
    required bool active,
    required String query,
  }) {
    // No clients while building means the list is new, so its scroll offset
    // is back at the top and the row must be found again. Playback starting
    // shows it again too: Play after a stop keeps the same station current.

    if (!controller.hasClients || active && !_wasActive) _shown = null;
    _wasActive = active;
    final want = stationId == null || index < 0 ? null : '$stationId\n$query';
    if (want == _shown) return;
    _shown = want;
    if (want == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(index, count));
  }

  /// Bring the row into view, first jumping near where it should be if it is
  /// too far off screen to have been built. A few tries, as row heights vary
  /// and the guess may land short.

  void _reveal(int index, int count, [int tries = 3]) {
    if (!controller.hasClients) return;
    final row = _row;
    if (row != null && row.mounted) {
      _ensure(row);
      return;
    }
    if (tries == 0 || count == 0) return;
    final pos = controller.position;
    final total = pos.maxScrollExtent + pos.viewportDimension;
    final guess = total * index / count - pos.viewportDimension / 2;
    controller.jumpTo(guess.clamp(0.0, pos.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(index, count, tries - 1),
    );
  }

  /// Scroll only as far as needed: each policy is a no-op when that edge of
  /// the row is already inside the viewport.

  Future<void> _ensure(BuildContext row) async {
    const duration = Duration(milliseconds: 300);
    await Scrollable.ensureVisible(
      row,
      duration: duration,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    if (!row.mounted) return;
    await Scrollable.ensureVisible(
      row,
      duration: duration,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }
}

/// Wraps every row, telling [follower] where the row on air is built.
///
/// Every row carries one, [active] or not, so that the station on air
/// changing never changes a row's widget structure; in a reorderable list
/// that would unmount the row and cancel a drag.

class OnAirMarker extends StatefulWidget {
  const OnAirMarker({
    super.key,
    required this.follower,
    required this.active,
    required this.child,
  });

  final OnAirFollower follower;
  final bool active;
  final Widget child;

  @override
  State<OnAirMarker> createState() => _OnAirMarkerState();
}

class _OnAirMarkerState extends State<OnAirMarker> {
  @override
  void dispose() {
    if (widget.follower._row == context) widget.follower._row = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active) {
      widget.follower._row = context;
    } else if (widget.follower._row == context) {
      widget.follower._row = null;
    }
    return widget.child;
  }
}
