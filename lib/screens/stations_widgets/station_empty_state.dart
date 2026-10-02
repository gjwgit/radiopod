/// StationEmptyState — what the Stations screen shows before anything is saved.
///
// Time-stamp: <Tuesday 2026-09-29 16:07:27 +1000 Graham Williams>
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

import 'package:gap/gap.dart';

/// An empty state that says what to do next rather than just that the list is
/// empty. The two routes into a library are Search and an imported playlist
/// file, so both are named.

class StationEmptyState extends StatelessWidget {
  final bool filtered;

  const StationEmptyState({super.key, required this.filtered});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off : Icons.radio,
              size: 56,
              color: cs.onSurfaceVariant,
            ),
            const Gap(16),
            Text(
              filtered ? 'No matching stations' : 'No stations yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(8),
            Text(
              filtered
                  ? 'No saved station matches what you typed. Clear the '
                        'filter to see your whole library.'
                  : 'Use the Search button 🔍 to find stations in the '
                        'Radio-Browser database, or the Export/Import '
                        'button 📥 to import a M3U or PLS playlist you '
                        'already have, perhaps from another app or '
                        'perhaps from a friend.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
