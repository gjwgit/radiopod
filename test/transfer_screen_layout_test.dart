/// Tests that the Export/Import screen stays at the top of its viewport.
///
// Time-stamp: <Thursday 2026-09-25 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:radiopod/screens/transfer_screen.dart';
import 'package:radiopod/services/app_provider.dart';

/// Pump the screen the way the app scaffold does, inside a [Center].
///
/// The centre is the point of the test. This screen's content is shorter
/// than the window, and a parent that centres a child not filling the height
/// is what pushed "Import" down the page. Reproducing that here is what makes
/// the test meaningful — wrapped in a plain SizedBox it would pass either way.

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => AppProvider()..loadForTest(const [], const []),
        child: const Scaffold(
          body: Center(child: TransferScreen()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Import sits at the top, not centred in the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester);

    final heading = tester.getTopLeft(find.text('Import'));

    // The screen pads by 24. Anything much beyond that is the content having
    // been centred rather than laid out from the top. The bound is generous
    // so a change of type size does not fail it, and still far below the
    // hundreds of pixels a centred short page produced.

    expect(
      heading.dy,
      lessThan(80),
      reason: 'Import is ${heading.dy}px down a 1400px viewport, so the '
          'content is being centred rather than starting at the top',
    );
  });

  testWidgets('both headings are present and in order', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester);

    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Import')).dy,
      lessThan(tester.getTopLeft(find.text('Export')).dy),
    );
  });

  testWidgets('a viewport shorter than the content still scrolls', (
    tester,
  ) async {
    // The fill must not turn into a fixed height: on a short window the
    // content has to remain reachable.

    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester);

    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -260),
    );
    await tester.pump();

    expect(find.text('Export'), findsOneWidget);
  });
}
