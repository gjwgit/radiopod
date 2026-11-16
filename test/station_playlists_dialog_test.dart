/// Tests for the playlists of one station, opened by a swipe right.
///
// Time-stamp: <Monday 2026-11-16 10:00:00 +1100 Graham Williams>
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
import 'package:radiopod/screens/stations_widgets/station_playlists_dialog.dart';
import 'package:radiopod/services/app_provider.dart';

const _radio = Station(id: 's1', name: 'Classic', url: 'https://x.example/1');

Future<AppProvider> _pump(
  WidgetTester tester, {
  List<Playlist> playlists = const [
    Playlist(id: 'p1', name: 'Drive', stationIds: ['s1']),
    Playlist(id: 'p2', name: 'Night'),
  ],
}) async {
  final provider = AppProvider()..loadForTest(const [_radio], playlists);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: StationPlaylistsDialog(station: _radio)),
    ),
  );

  return provider;
}

bool? _ticked(WidgetTester tester, String name) => tester
    .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, name))
    .value;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('each playlist is ticked where the station is in it', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Playlists for Classic'), findsOneWidget);
    expect(_ticked(tester, 'Drive'), isTrue);
    expect(_ticked(tester, 'Night'), isFalse);
  });

  testWidgets('a tick adds, an untick removes', (tester) async {
    final provider = await _pump(tester);

    await tester.tap(find.text('Night'));
    await tester.pump();
    expect(provider.playlists.last.stationIds, ['s1']);
    expect(_ticked(tester, 'Night'), isTrue);

    await tester.tap(find.text('Drive'));
    await tester.pump();
    expect(provider.playlists.first.stationIds, isEmpty);
  });

  testWidgets('New playlist creates one with the station in it', (
    tester,
  ) async {
    final provider = await _pump(tester, playlists: const []);
    expect(find.textContaining('no playlists yet'), findsOneWidget);

    await tester.tap(find.text('New playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Morning');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(provider.playlists.single.name, 'Morning');
    expect(provider.playlists.single.stationIds, ['s1']);
    expect(_ticked(tester, 'Morning'), isTrue);
  });
}
