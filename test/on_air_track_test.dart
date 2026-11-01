/// Tests for the track on air and the details only Properties shows.
///
// Time-stamp: <Wednesday 2026-10-28 12:00:00 +1100 Graham Williams>
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
import 'package:radiopod/screens/stations_widgets/on_air_track.dart';
import 'package:radiopod/screens/stations_widgets/station_details.dart';

const _station = Station(
  id: 's1',
  name: 'ABC Classic',
  url: 'http://example.com/classic',
  favicon: 'https://example.com/logo.png',
  stationUuid: '0001-uuid',
  country: 'Australia',
);

/// A track far longer than a row's single line can hold.

const _long =
    'Johann Sebastian Bach — Mass in B minor, BWV 232: Gloria in excelsis '
    'Deo, performed by the Monteverdi Choir and English Baroque Soloists';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('the track on air is shown whole', (tester) async {
    await _pump(tester, const OnAirTrack(track: _long));

    expect(find.text('On air now'), findsOneWidget);
    expect(find.text(_long), findsOneWidget);
  });

  testWidgets('a station announcing nothing says so', (tester) async {
    await _pump(tester, const OnAirTrack());

    expect(
      find.text('This station is not saying what is playing.'),
      findsOneWidget,
    );
  });

  testWidgets('full details add the logo and Radio-Browser id', (tester) async {
    await _pump(tester, const StationDetails(station: _station, full: true));

    expect(find.text('https://example.com/logo.png'), findsOneWidget);
    expect(find.text('0001-uuid'), findsOneWidget);
  });

  testWidgets('Search leaves them out', (tester) async {
    await _pump(tester, const StationDetails(station: _station));

    expect(find.text('https://example.com/logo.png'), findsNothing);
    expect(find.text('0001-uuid'), findsNothing);
  });
}
