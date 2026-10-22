/// SwipeToRemove — swipe a station row to the left to remove it.
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

/// A row that is removed by swiping it to the left, the same action as the
/// row's own delete or remove button.
///
/// 20261023 gjw Used by the Stations and Playlists screens. [confirm] is
/// asked before the row goes, and a false keeps it, so the library delete
/// keeps its confirmation; [onRemove] then runs as the row leaves.
///
/// The [key] must be the row's own stable key: inside a
/// ReorderableListView this widget is the item, and the list requires its
/// key there. It must also leave the list as soon as [onRemove] runs, or
/// Dismissible asserts that a dismissed row is still in the tree;
/// AppProvider notifies its listeners before it saves, so it does.

class SwipeToRemove extends StatelessWidget {
  const SwipeToRemove({
    required super.key,
    required this.child,
    required this.onRemove,
    this.confirm,
  });

  final Widget child;
  final VoidCallback onRemove;
  final Future<bool> Function()? confirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      confirmDismiss: confirm == null ? null : (_) => confirm!(),
      onDismissed: (_) => onRemove(),
      background: ColoredBox(
        color: scheme.errorContainer,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
          ),
        ),
      ),
      child: child,
    );
  }
}
