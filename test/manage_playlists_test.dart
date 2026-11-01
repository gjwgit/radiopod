/// Tests for the Manage playlists grid.
///
// Time-stamp: <Sunday 2026-10-25 14:00:00 +1100 Graham Williams>
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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/playlists_widgets/manage_playlists_dialog.dart';
import 'package:radiopod/screens/playlists_widgets/playlists_bar.dart';
import 'package:radiopod/services/app_provider.dart';

const _radio = Station(id: 's1', name: 'Classic', url: 'https://x.example/1');
const _podcast = Station(
  id: 's2',
  name: 'Future Tense',
  url: 'https://x.example/feed.xml',
  isPodcast: true,
);

Future<AppProvider> _pump(WidgetTester tester, {String filter = ''}) async {
  final provider = AppProvider()
    ..loadForTest(
      const [_radio, _podcast],
      const [
        Playlist(id: 'p1', name: 'Drive', stationIds: ['s1']),
        Playlist(id: 'p2', name: 'Night'),
      ],
    );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: ManagePlaylistsDialog(initialFilter: filter)),
    ),
  );

  return provider;
}

Checkbox _box(WidgetTester tester, String label) => tester.widget<Checkbox>(
  find.byWidgetPredicate((w) => w is Checkbox && w.semanticLabel == label),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a box per station and playlist, ticked where it belongs', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(Checkbox), findsNWidgets(4));
    expect(_box(tester, 'Classic in Drive').value, isTrue);
    expect(_box(tester, 'Classic in Night').value, isFalse);
    expect(_box(tester, 'Future Tense in Drive').value, isFalse);
  });

  testWidgets('a tick adds, an untick removes', (tester) async {
    final provider = await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Future Tense in Night'));
    await tester.pump();
    expect(provider.playlists.last.stationIds, ['s2']);

    await tester.tap(find.bySemanticsLabel('Classic in Drive'));
    await tester.pump();
    expect(provider.playlists.first.stationIds, isEmpty);
  });

  testWidgets('the filter starts with the page\'s text', (tester) async {
    await _pump(tester, filter: 'future');

    expect(find.text('Classic'), findsNothing);
    expect(find.text('Future Tense'), findsOneWidget);
  });

  testWidgets('the filter and Manage playlists fit a phone', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final filter = TextEditingController(text: 'a long filter typed in');
    addTearDown(filter.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaylistsBar(
            controller: filter,
            onChanged: () {},
            canManage: true,
            trailing: IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.playlist_add_check), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);
  });
}
