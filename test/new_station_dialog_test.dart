/// Tests for adding a station by hand.
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
import 'package:radiopod/screens/stations_widgets/new_station_dialog.dart';

const _saved = 'http://already.example/stream';

/// Open the dialog and hand back whatever it returns.

Future<Station?> _open(WidgetTester tester) async {
  Station? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showNewStationDialog(
                context,
                isDuplicate: (url) => url == _saved,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return result;
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(
    find.ancestor(of: find.text(label), matching: find.byType(TextField)),
    text,
  );
  await tester.pump();
}

void main() {
  group('isPlayableUrl', () {
    test('accepts plain http, which many stations still use', () {
      expect(isPlayableUrl('http://abc.streamguys1.com/live/x'), isTrue);
    });

    test('accepts https', () {
      expect(isPlayableUrl('https://example.com/stream'), isTrue);
    });

    test('rejects a bare host with no scheme', () {
      expect(isPlayableUrl('example.com/stream'), isFalse);
    });

    test('rejects a scheme just_audio cannot open', () {
      expect(isPlayableUrl('ftp://example.com/stream'), isFalse);
      expect(isPlayableUrl('file:///tmp/x.mp3'), isFalse);
    });

    test('rejects a scheme with no host', () {
      expect(isPlayableUrl('http://'), isFalse);
    });

    test('tolerates surrounding whitespace', () {
      expect(isPlayableUrl('  https://example.com/s  '), isTrue);
    });
  });

  group('the dialog', () {
    testWidgets('cannot add until both a name and an address are given', (
      tester,
    ) async {
      await _open(tester);

      Finder add() => find.widgetWithText(FilledButton, 'Add station');
      expect(tester.widget<FilledButton>(add()).onPressed, isNull);

      await _type(tester, 'Name', 'Local FM');
      expect(
        tester.widget<FilledButton>(add()).onPressed,
        isNull,
        reason: 'a name alone is not enough',
      );

      await _type(tester, 'Stream URL', 'https://local.example/stream');
      expect(tester.widget<FilledButton>(add()).onPressed, isNotNull);
    });

    testWidgets('says nothing about an address box not yet typed in', (
      tester,
    ) async {
      // Complaining before the user has finished is just noise.

      await _open(tester);

      expect(find.textContaining('starting with http'), findsNothing);
    });

    testWidgets('explains an address that is not a stream address', (
      tester,
    ) async {
      await _open(tester);
      await _type(tester, 'Stream URL', 'not a url');

      expect(find.textContaining('starting with http'), findsOneWidget);
    });

    testWidgets('refuses a stream address already in the library', (
      tester,
    ) async {
      await _open(tester);
      await _type(tester, 'Name', 'Duplicate');
      await _type(tester, 'Stream URL', _saved);

      expect(find.textContaining('already saved'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Add station'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('returns the station it was given', (tester) async {
      Station? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showNewStationDialog(
                    context,
                    isDuplicate: (url) => url == _saved,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _type(tester, 'Name', '  Local FM  ');
      await _type(tester, 'Stream URL', '  https://local.example/s  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Add station'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.name, 'Local FM', reason: 'trimmed');
      expect(captured!.url, 'https://local.example/s', reason: 'trimmed');
      expect(captured!.id, isNotEmpty);
      expect(captured!.isHls, isFalse);
    });

    testWidgets('marks an .m3u8 address as HLS', (tester) async {
      // The same test Search applies, so a hand-added HLS stream is not a
      // mystery when it stops after a minute on the desktop.

      Station? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showNewStationDialog(
                    context,
                    isDuplicate: (_) => false,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _type(tester, 'Name', 'Segmented');
      await _type(tester, 'Stream URL', 'https://x.example/live/news.m3u8');
      await tester.tap(find.widgetWithText(FilledButton, 'Add station'));
      await tester.pumpAndSettle();

      expect(captured!.isHls, isTrue);
    });

    testWidgets('offers no Download, a new station advertising nothing', (
      tester,
    ) async {
      await _open(tester);

      final download = find.widgetWithText(OutlinedButton, 'Download');
      expect(tester.widget<OutlinedButton>(download).onPressed, isNull);
      expect(find.textContaining('nothing to download'), findsOneWidget);
    });
  });
}
