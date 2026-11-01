/// Tests for SwipeToRemove: a swipe LEFT removes, unless refused.
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

import 'package:radiopod/widgets/swipe_to_remove.dart';

Future<List<String>> _pump(
  WidgetTester tester, {
  Future<bool> Function()? confirm,
}) async {
  final rows = ['a', 'b'];
  final removed = <String>[];

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ListView(
            children: [
              for (final r in rows)
                SwipeToRemove(
                  key: ValueKey(r),
                  confirm: confirm,
                  onRemove: () => setState(() {
                    rows.remove(r);
                    removed.add(r);
                  }),
                  child: ListTile(title: Text('row $r')),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  return removed;
}

void main() {
  testWidgets('a swipe left removes the row', (tester) async {
    final removed = await _pump(tester);

    await tester.fling(find.text('row a'), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();

    expect(removed, ['a']);
    expect(find.text('row a'), findsNothing);
  });

  testWidgets('a swipe right does nothing', (tester) async {
    final removed = await _pump(tester);

    await tester.fling(find.text('row a'), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();

    expect(removed, isEmpty);
  });

  testWidgets('a refused confirmation keeps the row', (tester) async {
    final removed = await _pump(tester, confirm: () async => false);

    await tester.fling(find.text('row a'), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();

    expect(removed, isEmpty);
    expect(find.text('row a'), findsOneWidget);
  });
}
