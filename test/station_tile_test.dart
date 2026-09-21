/// Widget tests for StationTile.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/widgets/station_tile.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: child)),
);

void main() {
  const plain = Station(
    id: 's1',
    name: 'Alpha FM',
    url: 'https://live.example/a',
  );

  const detailed = Station(
    id: 's2',
    name: 'Beta FM',
    url: 'https://live.example/b',
    country: 'Australia',
    codec: 'MP3',
    bitrate: 128,
  );

  testWidgets('shows the station name', (tester) async {
    await _pump(tester, const StationTile(station: plain));

    expect(find.text('Alpha FM'), findsOneWidget);
  });

  testWidgets('shows a subtitle only when there is metadata', (tester) async {
    await _pump(tester, const StationTile(station: plain));
    expect(find.text('Australia · MP3 · 128 kbps'), findsNothing);

    await _pump(tester, const StationTile(station: detailed));
    expect(find.text('Australia · MP3 · 128 kbps'), findsOneWidget);
  });

  testWidgets('falls back to a radio icon with no favicon', (tester) async {
    await _pump(tester, const StationTile(station: plain));

    expect(find.byIcon(Icons.radio), findsOneWidget);
  });

  testWidgets('reports taps', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      StationTile(station: plain, onTap: () => taps++),
    );
    await tester.tap(find.text('Alpha FM'));

    expect(taps, 1);
  });

  testWidgets('renders the caller-supplied trailing widget', (tester) async {
    await _pump(
      tester,
      const StationTile(
        station: plain,
        trailing: Icon(Icons.remove_circle_outline),
      ),
    );

    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
  });

  testWidgets('marks the selected station in bold', (tester) async {
    await _pump(tester, const StationTile(station: plain, selected: true));
    final text = tester.widget<Text>(find.text('Alpha FM'));

    expect(text.style?.fontWeight, FontWeight.w600);
  });
}
