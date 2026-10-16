/// Pod refresh tests — the dialog says when no Pod was asked.
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

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/widgets/pod_refresh_action.dart';

Future<void> _tapRefresh(
  WidgetTester tester, {
  required bool changed,
  bool Function()? isOnPod,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => handlePodRefresh(
            context: context,
            onRefresh: () async => changed,
            isOnPod: isOnPod,
          ),
          child: const Text('Refresh'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Refresh'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('logged out, says no Pod was read', (tester) async {
    await _tapRefresh(tester, changed: false, isOnPod: () => false);

    expect(find.text('Not logged in'), findsOneWidget);
    expect(find.text('Already up to date'), findsNothing);
  });

  testWidgets('on a Pod with no changes, says up to date', (tester) async {
    await _tapRefresh(tester, changed: false, isOnPod: () => true);

    expect(find.text('Already up to date'), findsOneWidget);
  });

  testWidgets('on a Pod with changes, says updated', (tester) async {
    await _tapRefresh(tester, changed: true, isOnPod: () => true);

    expect(find.text('Data updated'), findsOneWidget);
  });

  testWidgets('without isOnPod, behaves as before', (tester) async {
    await _tapRefresh(tester, changed: false);

    expect(find.text('Already up to date'), findsOneWidget);
  });
}
