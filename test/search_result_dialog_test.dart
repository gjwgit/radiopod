/// Tests for the search result's information dialog.
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

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/search_widgets/search_result_actions.dart';
import 'package:radiopod/services/podcast_index.dart';

Future<void> _open(
  WidgetTester tester,
  Station station, {
  bool saved = false,
  VoidCallback? onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SearchResultActions(
          station: station,
          saved: saved,
          onSave: onSave ?? () {},
        ),
      ),
    ),
  );
  await tester.tap(find.byIcon(Icons.info_outline));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a station shows its details and the stream', (tester) async {
    await _open(
      tester,
      const Station(
        id: 's1',
        name: 'Alpha FM',
        url: 'https://live.example/a',
        country: 'Australia',
        codec: 'MP3',
      ),
    );

    expect(find.text('Alpha FM'), findsOneWidget);
    expect(find.text('Australia · MP3'), findsOneWidget);
    expect(find.text('Stream'), findsOneWidget);
  });

  testWidgets('a podcast shows what it is about and its episodes', (
    tester,
  ) async {
    final podcast = podcastsFromSearch(
      jsonEncode({
        'feeds': [
          {
            'title': 'Future Tense',
            'url': 'https://x.example/feed.xml',
            'author': 'ABC Australia',
            'description': 'Technology and society.',
            'episodeCount': 120,
          },
        ],
      }),
    ).single;
    await _open(tester, podcast);

    expect(find.text('Podcast · ABC Australia · 120 episodes'), findsOneWidget);
    expect(find.text('Technology and society.'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
  });

  testWidgets('Save closes the dialog and saves', (tester) async {
    var saves = 0;
    await _open(
      tester,
      const Station(id: 's1', name: 'Alpha FM', url: 'https://live.example/a'),
      onSave: () => saves++,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a saved result offers no Save', (tester) async {
    await _open(
      tester,
      const Station(id: 's1', name: 'Alpha FM', url: 'https://live.example/a'),
      saved: true,
    );
    final button = tester.widget<ButtonStyleButton>(
      find.widgetWithText(FilledButton, 'Saved'),
    );

    expect(button.onPressed, isNull);
  });
}
