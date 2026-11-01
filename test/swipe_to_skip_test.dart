/// Tests for SwipeToSkip: left skips, right unskips, the row stays.
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

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/screens/podcast_widgets/swipe_to_skip.dart';

void main() {
  Future<List<bool>> pump(WidgetTester tester) async {
    var skipped = false;
    final seen = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ListView(
              children: [
                SwipeToSkip(
                  key: const ValueKey('e1'),
                  skipped: skipped,
                  onSkip: (skip) => setState(() {
                    skipped = skip;
                    seen.add(skip);
                  }),
                  child: const ListTile(title: Text('episode')),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return seen;
  }

  testWidgets('left skips, right unskips, and the row stays', (tester) async {
    final seen = await pump(tester);

    await tester.fling(find.text('episode'), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    expect(seen, [true]);
    expect(find.text('episode'), findsOneWidget);

    await tester.fling(find.text('episode'), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();
    expect(seen, [true, false]);
    expect(find.text('episode'), findsOneWidget);
  });

  testWidgets('only the swipe that changes the row is offered', (tester) async {
    final seen = await pump(tester);

    // In its turn, so right does nothing.
    await tester.fling(find.text('episode'), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();
    expect(seen, isEmpty);

    // Skipped, so a second left does nothing.
    await tester.fling(find.text('episode'), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.text('episode'), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    expect(seen, [true]);
  });
}
