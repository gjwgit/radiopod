/// Tests for storing and reading a station's icon.
///
// Time-stamp: <Wednesday 2026-09-23 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/station_icon.dart';

/// A real 4x4 PNG, produced by an image library rather than written out by
/// hand — a hand-assembled one had a bad CRC and the codec rejected it,
/// which looked exactly like the encoder being broken.

final _tinyPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04,
  0x08, 0x06, 0x00, 0x00, 0x00, 0xA9, 0xF1, 0x9E, 0x7E, 0x00, 0x00, 0x00,
  0x15, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xDC, 0x92, 0xAC, 0xF5,
  0x9F, 0x01, 0x09, 0x30, 0x31, 0xA0, 0x01, 0xC2, 0x02, 0x00, 0x94, 0x60,
  0x02, 0x48, 0x32, 0xAD, 0x7F, 0xA1, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('encodeStationIcon', () {
    test('turns image bytes into something storable', () async {
      final encoded = await encodeStationIcon(_tinyPng);

      expect(encoded, isNotNull);
      expect(() => base64Decode(encoded!), returnsNormally);
    });

    test('re-encodes as PNG whatever came in', () async {
      // The stored bytes always start with the PNG signature, so a station
      // that advertised an ICO or a JPEG still draws on every platform.

      final encoded = await encodeStationIcon(_tinyPng);
      final bytes = base64Decode(encoded!);

      expect(bytes.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
    });

    test('returns null for bytes that are not an image', () async {
      final junk = Uint8List.fromList(utf8.encode('<html>404</html>'));

      expect(await encodeStationIcon(junk), isNull);
    });

    test('returns null for empty bytes', () async {
      expect(await encodeStationIcon(Uint8List(0)), isNull);
    });
  });

  group('decodeStationIcon', () {
    test('round-trips what encode produced', () async {
      final encoded = await encodeStationIcon(_tinyPng);

      expect(decodeStationIcon(encoded), isNotNull);
    });

    test('gives back the SAME list each time, so icons do not flash', () {
      // MemoryImage compares its bytes by identity, so a fresh Uint8List on
      // every build misses Flutter's image cache and re-decodes the picture.
      // That showed up as station icons flickering continuously while a
      // stream played, because the list rebuilds on each playback event.

      const encoded = 'aGVsbG8gd29ybGQ=';

      expect(
        identical(decodeStationIcon(encoded), decodeStationIcon(encoded)),
        isTrue,
      );
    });

    test('different icons stay distinct', () {
      final a = decodeStationIcon('aGVsbG8gd29ybGQ=');
      final b = decodeStationIcon('Z29vZGJ5ZSB3b3JsZA==');

      expect(identical(a, b), isFalse);
    });

    test('a station with no icon decodes to null', () {
      expect(decodeStationIcon(null), isNull);
      expect(decodeStationIcon(''), isNull);
    });

    test('unreadable stored data is discarded, not thrown', () {
      // The value comes from the Pod and may have been written by an older
      // version or edited by hand. A bad icon must not stop the station
      // appearing in the list.

      expect(decodeStationIcon('not base64 at all !!'), isNull);
    });
  });

  group('the station field', () {
    test('round-trips through JSON', () {
      const s = Station(
        id: 's1',
        name: 'With art',
        url: 'https://live.example/a',
        icon: 'AAAA',
      );

      expect(Station.fromJson(s.toJson()).icon, 'AAAA');
    });

    test('is left out of JSON when absent, keeping the Pod small', () {
      const s = Station(id: 's1', name: 'Bare', url: 'https://live.example/a');

      expect(s.toJson().containsKey('icon'), isFalse);
    });

    test('a station saved before icons existed reads as null', () {
      final s = Station.fromJson({
        'id': 's1',
        'name': 'Old',
        'url': 'https://live.example/o',
      });

      expect(s.icon, isNull);
    });

    test('copyWith can set an icon and clear it again', () {
      const s = Station(id: 's1', name: 'n', url: 'https://live.example/n');

      expect(s.copyWith(icon: 'AAAA').icon, 'AAAA');
      expect(s.copyWith(icon: 'AAAA').copyWith(icon: null).icon, isNull);
    });

    test('copyWith leaves the icon alone when not mentioned', () {
      const s = Station(
        id: 's1',
        name: 'n',
        url: 'https://live.example/n',
        icon: 'AAAA',
      );

      expect(s.copyWith(name: 'Renamed').icon, 'AAAA');
    });
  });
}
