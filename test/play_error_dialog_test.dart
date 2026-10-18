/// Tests for telling a podcast with nothing left from a station that failed.
///
// Time-stamp: <Sunday 2026-10-18 06:00:00 +1100 Graham Williams>
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

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/cast_playback.dart';
import 'package:radiopod/widgets/error_dialog.dart';

const _podcast = Station(
  id: 'p1',
  name: 'Daily Mass Readings',
  url: 'https://x.example/feed.xml',
  isPodcast: true,
);

Future<void> _show(WidgetTester tester, Object error) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showPlayError(
            context,
            station: _podcast,
            error: error,
            otherwise: 'The stream could not be reached.',
          ),
          child: const Text('go'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  test('says whether there are none, or none left', () {
    const none = NothingToPlay('X', noEpisodes: true);
    const heard = NothingToPlay('X', noEpisodes: false);

    expect(none.title, 'No episodes yet');
    expect(heard.title, 'Nothing left to play');
    expect(heard.message, contains('Mark as not played'));
    expect(heard.toString(), heard.message);
  });

  // 20261018 gjw Every episode heard was reported as "The stream could not
  // be reached", with advice to find the podcast again in Search.

  testWidgets('a podcast with every episode heard is not called a fault', (
    tester,
  ) async {
    await _show(
      tester,
      const NothingToPlay('Daily Mass Readings', noEpisodes: false),
    );

    expect(find.text('Nothing left to play'), findsOneWidget);
    expect(find.textContaining('could not be reached'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('a real failure still reads as one', (tester) async {
    await _show(tester, Exception('connection refused'));

    expect(find.text('Cannot play Daily Mass Readings'), findsOneWidget);
    expect(find.textContaining('could not be reached'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
