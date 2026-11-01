/// Tests for reordering the stations inside a playlist.
///
// Time-stamp: <Monday 2026-10-05 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
//
/// Authors: Graham Williams

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';

const _a = Station(id: 's1', name: 'Alpha', url: 'https://live.example/a');
const _b = Station(id: 's2', name: 'Bravo', url: 'https://live.example/b');
const _c = Station(id: 's3', name: 'Charlie', url: 'https://live.example/c');

AppProvider _provider({List<String> ids = const ['s1', 's2', 's3']}) =>
    AppProvider()..loadForTest(
      const [_a, _b, _c],
      [Playlist(id: 'p1', name: 'Drive', stationIds: ids)],
    );

List<String> _order(AppProvider p) =>
    p.stationsOf(p.playlists.first).map((s) => s.id).toList();

AppProvider _manyPlaylists() => AppProvider()
  ..loadForTest(
    const [_a, _b, _c],
    const [
      Playlist(id: 'p1', name: 'Drive', stationIds: ['s1']),
      Playlist(id: 'p2', name: 'News', stationIds: ['s2']),
      Playlist(id: 'p3', name: 'Night', stationIds: ['s3']),
    ],
  );

void main() {
  // 20261005 gjw Two different orders, deliberately kept apart: the order OF
  // the playlists, and the order of stations WITHIN one. The first is what
  // the driver scrolls past in the car before reaching All Stations.

  group('reorderPlaylist', () {
    test('moves a playlist down', () async {
      final provider = _manyPlaylists();

      await provider.reorderPlaylist(0, 2);

      expect(provider.playlists.map((p) => p.id), ['p2', 'p3', 'p1']);
    });

    test('moves a playlist up', () async {
      final provider = _manyPlaylists();

      await provider.reorderPlaylist(2, 0);

      expect(provider.playlists.map((p) => p.id), ['p3', 'p1', 'p2']);
    });

    test('the stations inside are untouched', () async {
      final provider = _manyPlaylists();

      await provider.reorderPlaylist(0, 2);

      expect(provider.playlists.firstWhere((p) => p.id == 'p1').stationIds, [
        's1',
      ]);
    });

    test('moving to the same place changes nothing', () async {
      final provider = _manyPlaylists();

      await provider.reorderPlaylist(1, 1);

      expect(provider.playlists.map((p) => p.id), ['p1', 'p2', 'p3']);
    });

    test('an out of range index is ignored', () async {
      final provider = _manyPlaylists();

      await provider.reorderPlaylist(9, 0);

      expect(provider.playlists.map((p) => p.id), ['p1', 'p2', 'p3']);
    });
  });

  group('reorderInPlaylist', () {
    test('moves a station down', () async {
      final provider = _provider();

      await provider.reorderInPlaylist('p1', 0, 2);

      expect(_order(provider), ['s2', 's3', 's1']);
    });

    test('moves a station up', () async {
      final provider = _provider();

      await provider.reorderInPlaylist('p1', 2, 0);

      expect(_order(provider), ['s3', 's1', 's2']);
    });

    test('the order survives in stationIds, which is what the Pod stores', () {
      final provider = _provider();

      provider.reorderInPlaylist('p1', 0, 2);

      expect(provider.playlists.first.stationIds, ['s2', 's3', 's1']);
    });

    test('the library order is untouched', () async {
      final provider = _provider();

      await provider.reorderInPlaylist('p1', 0, 2);

      // A playlist is an ordering OF the library, not a reordering of it.

      expect(provider.stations.map((s) => s.id), ['s1', 's2', 's3']);
    });

    test('moving to the same place changes nothing', () async {
      final provider = _provider();

      await provider.reorderInPlaylist('p1', 1, 1);

      expect(_order(provider), ['s1', 's2', 's3']);
    });

    test('an unknown playlist is ignored', () async {
      final provider = _provider();

      await provider.reorderInPlaylist('nope', 0, 2);

      expect(_order(provider), ['s1', 's2', 's3']);
    });

    test('an out of range index is ignored', () async {
      final provider = _provider();

      await provider.reorderInPlaylist('p1', 7, 0);

      expect(_order(provider), ['s1', 's2', 's3']);
    });

    // 20261005 gjw The indices come from the VISIBLE rows, and stationsOf
    // skips ids whose station has gone from the library. So a dangling id
    // shifts every later position in stationIds away from the position the
    // user dragged. Deleting a station strips its id from every playlist, so
    // this should not arise — but getting it wrong would silently reorder a
    // different station than the one dragged, which is worth a test.

    group('with a dangling id', () {
      test('drags the station the user actually dragged', () async {
        final provider = _provider(ids: ['s1', 'gone', 's2', 's3']);

        expect(_order(provider), ['s1', 's2', 's3'], reason: 'visible rows');

        // Visible row 0 (s1) to the end of the visible list.

        await provider.reorderInPlaylist('p1', 0, 2);

        expect(_order(provider), ['s2', 's3', 's1']);
      });

      test('keeps the dangling id rather than silently dropping it', () async {
        final provider = _provider(ids: ['s1', 'gone', 's2', 's3']);

        await provider.reorderInPlaylist('p1', 0, 2);

        expect(provider.playlists.first.stationIds, contains('gone'));
      });
    });
  });
}
