/// Tests for spotting a station that refuses our country, and the dialog.
///
// Time-stamp: <Wednesday 2026-10-14 09:00:00 +1100 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
//
/// Authors: Graham Williams

library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/services/geo_block.dart';
import 'package:radiopod/widgets/geo_block_listener.dart';

void main() {
  group('blockedCountry', () {
    // The headers United Radio actually sent to a listener in Australia.

    test('names the refused country', () {
      expect(
        blockedCountry({'x-allowed-country': 'no', 'x-country': 'AU'}),
        'AU',
      );
    });

    test('a refusal without a country is still a refusal', () {
      expect(blockedCountry({'x-allowed-country': 'No'}), '');
    });

    test('an allowed country is not blocked', () {
      expect(
        blockedCountry({'x-allowed-country': 'yes', 'x-country': 'IT'}),
        isNull,
      );
    });

    test('an ordinary stream is not blocked', () {
      expect(blockedCountry({'content-type': 'audio/mpeg'}), isNull);
    });
  });

  group('GeoBlockListener', () {
    testWidgets('shows a dialog naming the station and country', (
      tester,
    ) async {
      final blocks = StreamController<GeoBlock>();
      addTearDown(blocks.close);

      await tester.pumpWidget(
        MaterialApp(
          home: GeoBlockListener(
            blocks: blocks.stream,
            child: const SizedBox(),
          ),
        ),
      );

      blocks.add((station: 'Roger Waters', country: 'AU'));
      await tester.pumpAndSettle();

      expect(find.text('Roger Waters is not available here'), findsOneWidget);
      expect(find.textContaining('(AU)'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
