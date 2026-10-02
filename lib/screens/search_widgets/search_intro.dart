/// SearchIntro — the Search screen before, and after an empty, search.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
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

/// Explains where results come from, which is the honest thing to show on a
/// screen that has not yet sent anything anywhere.
///
/// A [message] replaces the default when a search came back empty, so the
/// same layout covers both states.

class SearchIntro extends StatelessWidget {
  final String? message;

  const SearchIntro({super.key, this.message});

  static const _default =
      'Search the community-run Radio-Browser database of internet radio '
      'stations by name or genre.\n\n'
      'Nothing is sent until you search, and all that is sent then is your '
      'search text and the name of this app. RadioPod does not report what '
      'you listen to, here or anywhere else.';

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
              message == null ? Icons.travel_explore : Icons.search_off,
              size: 56,
              color: cs.onSurfaceVariant,
            ),
            const Gap(16),
            Text(
              message ?? _default,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
