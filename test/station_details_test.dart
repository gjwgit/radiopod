/// Tests for the read-only station facts in the properties dialog.
///
// Time-stamp: <Thursday 2026-09-25 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/stations_widgets/station_details.dart';

/// A station as Radio-Browser returns one, with everything filled in.

const _full = Station(
  id: 's1',
  name: 'ABC News Radio',
  url: 'http://abc.streamguys1.com/live/newsradio/icecast.audio',
  homepage: 'https://www.abc.net.au',
  country: 'Australia',
  state: 'NSW',
  language: 'english',
  codec: 'AAC+',
  bitrate: 56,
  tags: ['news', 'talk'],
);

/// A station as an M3U import leaves one: a name and a URL, nothing else.

const _bare = Station(
  id: 's2',
  name: 'From a file',
  url: 'http://example.com/stream',
);

Future<void> _pump(WidgetTester tester, Station station) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: StationDetails(station: station)),
      ),
    ),
  );
}

void main() {
  group('a station with everything', () {
    testWidgets('groups the facts as Information, Location and Audio', (
      tester,
    ) async {
      await _pump(tester, _full);

      expect(find.text('Information'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
    });

    testWidgets('shows each value against its label', (tester) async {
      await _pump(tester, _full);

      for (final v in [
        'english',
        'news, talk',
        'https://www.abc.net.au',
        'Australia',
        'NSW',
        '56 kbit/s',
        'AAC+',
        'http://abc.streamguys1.com/live/newsradio/icecast.audio',
      ]) {
        expect(find.text(v), findsOneWidget, reason: 'missing $v');
      }
    });

    testWidgets('offers a copy button for the stream and the homepage', (
      tester,
    ) async {
      await _pump(tester, _full);

      expect(find.byIcon(Icons.copy), findsNWidgets(2));
    });
  });

  group('a station with nothing but a name and a URL', () {
    testWidgets('shows the stream, since that is all there is', (tester) async {
      await _pump(tester, _bare);

      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('http://example.com/stream'), findsOneWidget);
    });

    testWidgets('omits the sections with nothing in them', (tester) async {
      // An M3U import carries no country, language or codec. Blank labels
      // would read as a failure rather than as nobody having typed them in.

      await _pump(tester, _bare);

      expect(find.text('Information'), findsNothing);
      expect(find.text('Location'), findsNothing);
      expect(find.text('Country'), findsNothing);
      expect(find.text('Language'), findsNothing);
    });

    testWidgets('omits an empty row within a section that is kept', (
      tester,
    ) async {
      await _pump(tester, _bare);

      expect(find.text('Stream'), findsOneWidget);
      expect(find.text('Codec'), findsNothing);
      expect(find.text('Bitrate'), findsNothing);
    });
  });

  group('edge cases', () {
    testWidgets('a zero bitrate is treated as unknown, not shown as 0', (
      tester,
    ) async {
      await _pump(tester, _bare.copyWith(bitrate: 0));

      expect(find.text('Bitrate'), findsNothing);
      expect(find.text('0 kbit/s'), findsNothing);
    });

    testWidgets('HLS is called out, since it is the one that breaks', (
      tester,
    ) async {
      await _pump(tester, _bare.copyWith(isHls: true));

      expect(find.text('Format'), findsOneWidget);
      expect(find.textContaining('HLS'), findsOneWidget);
    });

    testWidgets('a non-HLS station says nothing about format', (tester) async {
      await _pump(tester, _full);

      expect(find.text('Format'), findsNothing);
    });

    testWidgets('a whitespace-only field counts as absent', (tester) async {
      await _pump(tester, _bare.copyWith(country: '   '));

      expect(find.text('Location'), findsNothing);
    });
  });
}
