/// Tests for the stations an empty library starts with.
///
// Time-stamp: <Wednesday 2026-10-08 09:00:00 +1100 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
//
/// Authors: Graham Williams

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/constants/demo_stations.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/demo_seed.dart';

const _mine = Station(
  id: 'mine',
  name: 'My Own Station',
  url: 'https://live.example/mine',
);

AppProvider _provider({List<Station> stations = const []}) =>
    AppProvider()..loadForTest(stations, const <Playlist>[]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the starter stations themselves', () {
    test('there are five', () {
      expect(demoStations, hasLength(5));
    });

    // 20261008 gjw THE ORDER IS THE ORDER SHOWN. There is no sort field and
    // no alphabetical default (CLAUDE.md §5): the Stations screen lists these
    // as written, the car's All Stations folder does too, and an export
    // writes them this way. So the order is a decision, not an accident, and
    // a reshuffle while editing the list would be silent without this.

    test('they are in the intended order', () {
      expect(demoStations.map((s) => s.name), [
        'BBC World Service',
        'ABC Lounge',
        'Radio Paradise',
        'MANGORADIO',
        'Classic FM',
      ]);
    });

    test('seeding preserves that order', () async {
      final p = _provider();

      await p.seedIfEmpty();

      expect(p.stations.map((s) => s.name), demoStations.map((s) => s.name));
    });

    // 20261008 gjw These are written down rather than fetched, so nothing
    // checks them at run time. The stream and favicon URLs were fetched by
    // hand before being listed; what a test CAN still hold is their shape.

    test('every stream is https, so no station needs cleartext', () {
      for (final s in demoStations) {
        expect(
          Uri.parse(s.url).isScheme('https'),
          isTrue,
          reason: '${s.name} is not https',
        );
      }
    });

    test('every logo is https, which the web build requires', () {
      for (final s in demoStations) {
        expect(s.favicon, isNotNull, reason: '${s.name} has no logo');
        expect(
          Uri.parse(s.favicon!).isScheme('https'),
          isTrue,
          reason: '${s.name} logo is not https',
        );
      }
    });

    // HLS dies after one window under libmpv, which is how the desktop
    // plays audio (CLAUDE.md §7). A starter station that stops after fifty
    // seconds would be a poor first impression of the app.

    test('none is HLS', () {
      for (final s in demoStations) {
        expect(s.isHls, isFalse, reason: '${s.name} is HLS');
      }
    });

    test('no .m3u8 slipped in under a plain URL', () {
      for (final s in demoStations) {
        expect(s.url, isNot(contains('.m3u8')));
      }
    });

    // Stream URL is the de-duplication key for addStation and importEntries
    // (CLAUDE.md §5), so two starter stations sharing one would collapse.

    test('the stream URLs are distinct', () {
      final urls = demoStations.map((s) => s.url).toSet();

      expect(urls, hasLength(demoStations.length));
    });

    test('the ids are distinct, and fixed rather than generated', () {
      final ids = demoStations.map((s) => s.id).toSet();

      expect(ids, hasLength(demoStations.length));
      for (final s in demoStations) {
        expect(s.id, startsWith('demo-'));
      }
    });

    test('each has enough detail to show a subtitle', () {
      for (final s in demoStations) {
        expect(s.subtitle, isNotEmpty, reason: '${s.name} has no subtitle');
      }
    });
  });

  group('seeding', () {
    test('an empty library gets the starter stations', () async {
      final p = _provider();

      await p.seedIfEmpty();

      expect(p.stations.map((s) => s.id), demoStations.map((s) => s.id));
    });

    test('and is not seeded a second time', () async {
      final p = _provider();
      await p.seedIfEmpty();

      // The user deletes the lot.

      for (final s in [...p.stations]) {
        await p.deleteStation(s.id);
      }
      expect(p.stations, isEmpty);

      await p.seedIfEmpty();

      expect(
        p.stations,
        isEmpty,
        reason: 'deleting every station must not bring them back',
      );
    });

    test('a library with stations is left alone', () async {
      final p = _provider(stations: const [_mine]);

      await p.seedIfEmpty();

      expect(p.stations.map((s) => s.id), ['mine']);
    });

    // 20261008 gjw The case that was wrong first time. Someone who has had
    // their own stations since before this feature existed has never had the
    // flag set, so emptying their library would have seeded them.

    test('having had stations retires the offer for good', () async {
      final p = _provider(stations: const [_mine]);

      await p.seedIfEmpty();
      await p.deleteStation('mine');
      expect(p.stations, isEmpty);

      await p.seedIfEmpty();

      expect(p.stations, isEmpty);
    });

    test('the flag survives, so a later run does not seed', () async {
      await _provider().seedIfEmpty();

      expect(await DemoSeed.done, isTrue);

      final next = _provider();
      await next.seedIfEmpty();

      expect(next.stations, isEmpty);
    });
  });

  group('DemoSeed', () {
    test('a fresh device has not been seeded', () async {
      expect(await DemoSeed.done, isFalse);
    });

    test('markDone is remembered', () async {
      await DemoSeed.markDone();

      expect(await DemoSeed.done, isTrue);
    });

    test('resetForTest forgets it again', () async {
      await DemoSeed.markDone();
      await DemoSeed.resetForTest();

      expect(await DemoSeed.done, isFalse);
    });
  });
}
