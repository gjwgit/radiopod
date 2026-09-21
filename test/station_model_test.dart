/// Tests for the Station and Playlist models.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';

void main() {
  group('Station', () {
    const full = Station(
      id: 's1',
      name: 'ABC Classic',
      url: 'https://live.example/classic',
      homepage: 'https://abc.example',
      favicon: 'https://abc.example/icon.png',
      country: 'Australia',
      language: 'english',
      codec: 'MP3',
      bitrate: 128,
      tags: ['classical', 'news'],
      stationUuid: 'uuid-1',
    );

    test('JSON round-trips every field', () {
      final back = Station.fromJson(full.toJson());

      expect(back.id, full.id);
      expect(back.name, full.name);
      expect(back.url, full.url);
      expect(back.homepage, full.homepage);
      expect(back.favicon, full.favicon);
      expect(back.country, full.country);
      expect(back.language, full.language);
      expect(back.codec, full.codec);
      expect(back.bitrate, full.bitrate);
      expect(back.tags, full.tags);
      expect(back.stationUuid, full.stationUuid);
    });

    test('a minimal station round-trips and omits absent fields', () {
      const minimal = Station(id: 's2', name: 'Bare', url: 'http://x.example/');
      final json = minimal.toJson();

      expect(json.containsKey('country'), isFalse);
      expect(json.containsKey('tags'), isFalse);
      expect(Station.fromJson(json).name, 'Bare');
    });

    test('subtitle joins only the fields that are known', () {
      expect(full.subtitle, 'Australia · english · MP3 · 128 kbps');
      expect(const Station(id: 's', name: 'n', url: 'u').subtitle, isEmpty);
    });

    test('subtitle omits a zero bitrate', () {
      const s = Station(id: 's', name: 'n', url: 'u', codec: 'AAC', bitrate: 0);

      expect(s.subtitle, 'AAC');
    });

    test('copyWith can clear a nullable field', () {
      expect(full.copyWith(bitrate: null).bitrate, isNull);
      expect(full.copyWith(bitrate: null).name, full.name);
    });

    test('copyWith leaves untouched fields alone', () {
      expect(full.copyWith(name: 'Renamed').codec, 'MP3');
    });
  });

  group('Playlist', () {
    test('JSON round-trips', () {
      const p = Playlist(id: 'p1', name: 'Drive', stationIds: ['a', 'b']);
      final back = Playlist.fromJson(p.toJson());

      expect(back.id, 'p1');
      expect(back.name, 'Drive');
      expect(back.stationIds, ['a', 'b']);
    });

    test('a missing stationIds decodes as empty', () {
      final back = Playlist.fromJson({'id': 'p2', 'name': 'Empty'});

      expect(back.stationIds, isEmpty);
    });
  });
}
