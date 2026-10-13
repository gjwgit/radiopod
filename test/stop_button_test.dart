/// Widget tests for StopButton.
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

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:radiopod/widgets/stop_button.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

String _message(WidgetTester tester) =>
    tester.widget<MarkdownTooltip>(find.byType(MarkdownTooltip)).message;

void main() {
  testWidgets('stops when something is playing', (tester) async {
    var stopped = 0;
    await _pump(tester, StopButton(active: true, onStop: () => stopped++));

    await tester.tap(find.byIcon(Icons.stop));
    expect(stopped, 1);
  });

  testWidgets('after a stop the same button starts it again', (tester) async {
    var started = 0;
    await _pump(
      tester,
      StopButton(
        active: false,
        onStop: () {},
        onStart: () => started++,
        stationName: 'Jazz FM',
      ),
    );

    expect(find.byIcon(Icons.stop), findsNothing);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(started, 1);
    expect(_message(tester), contains('Start *Jazz FM* again'));
  });

  testWidgets('disabled before anything has played', (tester) async {
    await _pump(tester, StopButton(active: false, onStop: () {}));

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
    expect(_message(tester), contains('Nothing is playing'));
  });

  testWidgets('the tooltip names the station on air', (tester) async {
    await _pump(
      tester,
      StopButton(active: true, onStop: () {}, stationName: 'Jazz FM'),
    );

    expect(_message(tester), contains('*Jazz FM*'));
  });

  testWidgets('an unknown station still reads sensibly', (tester) async {
    await _pump(tester, StopButton(active: true, onStop: () {}));

    expect(_message(tester), contains('the station on air'));
  });
}
