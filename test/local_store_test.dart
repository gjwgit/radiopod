/// Tests for the device-local library store and the source switch.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
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

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/local_store.dart';

import 'support/debug_print_capture.dart';

const _a = Station(id: 's1', name: 'Zulu FM', url: 'https://live.example/z');
const _b = Station(id: 's2', name: 'Alpha FM', url: 'https://live.example/a');
const _c = Station(id: 's3', name: 'Charlie FM', url: 'https://live.example/c');

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
      await LocalStore.save(const [_a, _b], playlists, fromPod: false);

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
      await LocalStore.save(const [_a], const [], fromPod: false);
      await LocalStore.clear();

      final (stations, _) = await LocalStore.load();

      expect(stations, isEmpty);
    });

    test('unreadable stored data is discarded rather than thrown', () async {
      SharedPreferences.setMockInitialValues({
        'cached_stations': 'not json at all',
        'cached_playlists': '[]',
      });

      late final List<Station> stations;
      late final List<Playlist> playlists;
      final log = await captureDebugPrint(() async {
        (stations, playlists) = await LocalStore.load();
      });

      expect(stations, isEmpty);
      expect(playlists, isEmpty);
      expect(log.single, startsWith('[LocalStore] discarding unreadable'));
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

  group('LocalStore held library', () {
    const drive = Playlist(id: 'p1', name: 'Drive', stationIds: ['a']);

    test(
      'a Pod mirror holds the logged-out library, not overwrites it',
      () async {
        // The bug: logging in loaded the Pod and wrote it over the stations
        // saved while logged out, before Copy to Pod could find them.

        await LocalStore.save(const [_a, _b], const [drive], fromPod: false);
        await LocalStore.save(const [_c], const [], fromPod: true);

        final (mirror, _) = await LocalStore.load();
        final (held, heldPlaylists) = await LocalStore.loadHeld();

        expect(mirror.map((s) => s.name), ['Charlie FM']);
        expect(held.map((s) => s.name), ['Zulu FM', 'Alpha FM']);
        expect(heldPlaylists.single.name, 'Drive');
      },
    );

    test('refreshing the mirror holds nothing more', () async {
      await LocalStore.save(const [_a], const [], fromPod: false);
      await LocalStore.save(const [_b], const [], fromPod: true);
      await LocalStore.save(const [_c], const [], fromPod: true);

      final (held, _) = await LocalStore.loadHeld();

      expect(held.map((s) => s.name), ['Zulu FM']);
    });

    test('a copy from before origins were recorded counts as local', () async {
      SharedPreferences.setMockInitialValues({
        'cached_stations':
            '[{"id":"s1","name":"Old FM","url":"https://live.example/o"}]',
      });
      await LocalStore.save(const [_c], const [], fromPod: true);

      final (held, _) = await LocalStore.loadHeld();

      expect(held.single.name, 'Old FM');
    });

    test('logging in twice merges by stream URL, without duplicates', () async {
      await LocalStore.save(const [_a], const [drive], fromPod: false);
      await LocalStore.save(const [_c], const [], fromPod: true);
      await LocalStore.save(const [_a, _b], const [drive], fromPod: false);
      await LocalStore.save(const [_c], const [], fromPod: true);

      final (held, heldPlaylists) = await LocalStore.loadHeld();

      expect(held.map((s) => s.name), ['Zulu FM', 'Alpha FM']);
      expect(heldPlaylists, hasLength(1));
    });

    test('clearHeld leaves the mirror, clear removes both', () async {
      await LocalStore.save(const [_a], const [], fromPod: false);
      await LocalStore.save(const [_c], const [], fromPod: true);

      await LocalStore.clearHeld();
      expect((await LocalStore.loadHeld()).$1, isEmpty);
      expect((await LocalStore.load()).$1, isNotEmpty);

      await LocalStore.save(const [_a], const [], fromPod: false);
      await LocalStore.save(const [_c], const [], fromPod: true);
      await LocalStore.clear();
      expect((await LocalStore.loadHeld()).$1, isEmpty);
      expect((await LocalStore.load()).$1, isEmpty);
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
      await LocalStore.save(const [_a, _b], const [], fromPod: false);
      final provider = AppProvider()..loadForTest(const [], const []);

      expect(await provider.localOnlyCount(), 0);
    });
  });
}
