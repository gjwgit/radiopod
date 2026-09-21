/// Tests for the device-local library store and the source switch.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/local_store.dart';

const _a = Station(id: 's1', name: 'Zulu FM', url: 'https://live.example/z');
const _b = Station(id: 's2', name: 'Alpha FM', url: 'https://live.example/a');

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalStore', () {
    test('round-trips a library', () async {
      const playlists = [
        Playlist(id: 'p1', name: 'Drive', stationIds: ['s1']),
      ];
      await LocalStore.save(const [_a, _b], playlists);

      final (stations, back) = await LocalStore.load();

      expect(stations.map((s) => s.name), ['Zulu FM', 'Alpha FM']);
      expect(back.single.name, 'Drive');
      expect(back.single.stationIds, ['s1']);
    });

    test('an empty device returns two empty lists, not an error', () async {
      final (stations, playlists) = await LocalStore.load();

      expect(stations, isEmpty);
      expect(playlists, isEmpty);
    });

    test('clear forgets everything', () async {
      await LocalStore.save(const [_a], const []);
      await LocalStore.clear();

      final (stations, _) = await LocalStore.load();

      expect(stations, isEmpty);
    });

    test('unreadable stored data is discarded rather than thrown', () async {
      SharedPreferences.setMockInitialValues({
        'cached_stations': 'not json at all',
        'cached_playlists': '[]',
      });

      final (stations, playlists) = await LocalStore.load();

      expect(stations, isEmpty);
      expect(playlists, isEmpty);
    });

    test('reads a library written under the pre-rename keys', () async {
      // The keys are deliberately still `cached_*` so a library saved by an
      // earlier build survives the LibraryCache to LocalStore rename.

      SharedPreferences.setMockInitialValues({
        'cached_stations':
            '[{"id":"s1","name":"Old FM","url":"https://live.example/o"}]',
      });

      final (stations, _) = await LocalStore.load();

      expect(stations.single.name, 'Old FM');
    });
  });

  group('AppProvider source', () {
    test('defaults to local, so nothing assumes a Pod', () {
      expect(AppProvider().source, LibrarySource.local);
      expect(AppProvider().isLocal, isTrue);
    });

    test('a test provider can be pinned to either source', () {
      final local = AppProvider()..loadForTest(const [_a], const []);
      final pod = AppProvider()
        ..loadForTest(const [_a], const [], source: LibrarySource.pod);

      expect(local.isLocal, isTrue);
      expect(pod.isLocal, isFalse);
      expect(pod.source, LibrarySource.pod);
    });

    test('copyLocalToPod refuses while logged out', () async {
      final provider = AppProvider()..loadForTest(const [_a], const []);
      final (added, error) = await provider.copyLocalToPod();

      expect(added, 0);
      expect(error, isNotNull);
    });

    test('localOnlyCount is zero while logged out', () async {
      await LocalStore.save(const [_a, _b], const []);
      final provider = AppProvider()..loadForTest(const [], const []);

      expect(await provider.localOnlyCount(), 0);
    });
  });
}
