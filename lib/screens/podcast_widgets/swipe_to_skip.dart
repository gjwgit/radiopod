/// SwipeToSkip — swipe an episode left to skip it, right to unskip it.
///
// Time-stamp: <Friday 2026-10-23 10:00:00 +1100 Graham Williams>
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

/// An episode row that a swipe to the LEFT skips and a swipe to the RIGHT
/// unskips: the same as flipping the row's switch.
///
/// 20261023 gjw Only the swipe that would change the row is offered, so an
/// episode in its turn swipes left and a [skipped] one swipes right. A
/// skipped episode STAYS in the list, greyed, so the row springs back
/// rather than leaving: [onSkip] runs from confirmDismiss, which then
/// refuses the dismissal. Left matches the swipe that deletes a station.

class SwipeToSkip extends StatelessWidget {
  const SwipeToSkip({
    required super.key,
    required this.skipped,
    required this.onSkip,
    required this.child,
  });

  final bool skipped;
  final ValueChanged<bool> onSkip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: key!,
      direction: skipped
          ? DismissDirection.startToEnd
          : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onSkip(direction == DismissDirection.endToStart);

        return false;
      },
      background: _label(scheme, 'Unskip', Icons.playlist_add_check, false),
      secondaryBackground: _label(scheme, 'Skip', Icons.block, true),
      child: child,
    );
  }

  /// What shows behind the row as it moves, at the end it is uncovering.

  Widget _label(ColorScheme scheme, String text, IconData icon, bool right) {
    final style = TextStyle(color: scheme.onSecondaryContainer);
    final glyph = Icon(icon, color: scheme.onSecondaryContainer);

    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          spacing: 8,
          children: right
              ? [Text(text, style: style), glyph]
              : [glyph, Text(text, style: style)],
        ),
      ),
    );
  }
}
