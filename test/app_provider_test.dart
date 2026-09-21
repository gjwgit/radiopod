/// Tests for AppProvider library and playlist behaviour.
///
/// These run in test mode, so no Pod and no media session are touched.
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
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/utils/playlist_file.dart';

const _a = Station(id: 's1', name: 'Zulu FM', url: 'https://live.example/z');
const _b = Station(id: 's2', name: 'Alpha FM', url: 'https://live.example/a');

AppProvider _provider({
  List<Station> stations = const [_a, _b],
  List<Playlist> playlists = const [],
}) => AppProvider()..loadForTest(stations, playlists);

void main() {
  group('stations', () {
    test('stations keep library order rather than being sorted', () {
      expect(_provider().stations.map((s) => s.name), ['Zulu FM', 'Alpha FM']);
    });

    test('reorderStation moves a station down', () async {
      final p = _provider();
      await p.reorderStation(0, 1);

      expect(p.stations.map((s) => s.name), ['Alpha FM', 'Zulu FM']);
    });

    test('reorderStation moves a station up', () async {
      final p = _provider();
      await p.reorderStation(1, 0);

      expect(p.stations.map((s) => s.name), ['Alpha FM', 'Zulu FM']);
    });

    test('reorderStation uses onReorderItem indices, with no extra -1', () {
      // onReorderItem has already adjusted newIndex for the removed item, so
      // moving the first of three to index 2 must land it last. Subtracting
      // one again here — the old onReorder convention — would leave it in
      // the middle, which is the classic off-by-one in a drag-reorder.

      const c = Station(id: 's3', name: 'Mike FM', url: 'https://x.example/m');
      final p = _provider(stations: const [_a, _b, c]);
      p.reorderStation(0, 2);

      expect(p.stations.map((s) => s.name), ['Alpha FM', 'Mike FM', 'Zulu FM']);
    });

    test('reordering to the same position changes nothing', () async {
      final p = _provider();
      await p.reorderStation(1, 1);

      expect(p.stations.map((s) => s.name), ['Zulu FM', 'Alpha FM']);
    });

    test('a reordered library survives a round trip through JSON', () async {
      final p = _provider();
      await p.reorderStation(0, 1);

      // The order IS the storage — there is no sort field — so decoding the
      // saved list has to give back the same arrangement.

      final encoded = [for (final s in p.stations) s.toJson()];
      final back = [for (final j in encoded) Station.fromJson(j)];

      expect(back.map((s) => s.name), ['Alpha FM', 'Zulu FM']);
    });

    test('addStation refuses a duplicate stream URL', () async {
      final p = _provider();
      await p.addStation(
        const Station(
          id: 's9',
          name: 'Zulu again',
          url: 'https://live.example/z',
        ),
      );

      expect(p.stations, hasLength(2));
    });

    test('addStation accepts a new stream URL', () async {
      final p = _provider();
      await p.addStation(
        const Station(id: 's3', name: 'New', url: 'https://live.example/n'),
      );

      expect(p.stations, hasLength(3));
    });

    test('isSaved matches on URL, not name', () {
      final p = _provider();

      expect(p.isSaved('https://live.example/z'), isTrue);
      expect(p.isSaved('https://live.example/nope'), isFalse);
    });

    test('deleting a station also removes it from every playlist', () async {
      final p = _provider(
        playlists: const [
          Playlist(id: 'p1', name: 'One', stationIds: ['s1', 's2']),
          Playlist(id: 'p2', name: 'Two', stationIds: ['s1']),
        ],
      );
      await p.deleteStation('s1');

      expect(p.stations.map((s) => s.id), ['s2']);
      expect(p.playlists[0].stationIds, ['s2']);
      expect(p.playlists[1].stationIds, isEmpty);
    });
  });

  group('playlists', () {
    test('stationsOf keeps playlist order and skips missing stations', () {
      final p = _provider(
        playlists: const [
          Playlist(id: 'p1', name: 'One', stationIds: ['s2', 'gone', 's1']),
        ],
      );

      expect(p.stationsOf(p.playlists.single).map((s) => s.name), [
        'Alpha FM',
        'Zulu FM',
      ]);
    });

    test('addToPlaylist ignores a station already in the list', () async {
      final p = _provider(
        playlists: const [
          Playlist(id: 'p1', name: 'One', stationIds: ['s1']),
        ],
      );
      await p.addToPlaylist('p1', 's1');

      expect(p.playlists.single.stationIds, ['s1']);
    });

    test('removeFromPlaylist leaves the station in the library', () async {
      final p = _provider(
        playlists: const [
          Playlist(id: 'p1', name: 'One', stationIds: ['s1']),
        ],
      );
      await p.removeFromPlaylist('p1', 's1');

      expect(p.playlists.single.stationIds, isEmpty);
      expect(p.stations, hasLength(2));
    });

    test('deleting a playlist keeps its stations', () async {
      final p = _provider(
        playlists: const [
          Playlist(id: 'p1', name: 'One', stationIds: ['s1']),
        ],
      );
      await p.deletePlaylist('p1');

      expect(p.playlists, isEmpty);
      expect(p.stations, hasLength(2));
    });

    test('renamePlaylist changes only the name', () async {
      final p = _provider(
        playlists: const [
          Playlist(id: 'p1', name: 'One', stationIds: ['s1']),
        ],
      );
      await p.renamePlaylist('p1', 'Renamed');

      expect(p.playlists.single.name, 'Renamed');
      expect(p.playlists.single.stationIds, ['s1']);
    });
  });

  group('importEntries', () {
    const entries = <PlaylistEntry>[
      (name: 'Zulu FM', url: 'https://live.example/z'),
      (name: 'Brand New', url: 'https://live.example/new'),
    ];

    test('reuses an existing station and reports only the new ones', () async {
      final p = _provider();
      final (added, error) = await p.importEntries(
        entries,
        playlistName: 'Imported',
      );

      expect(error, isNull);
      expect(added, 1);
      expect(p.stations, hasLength(3));
    });

    test('the new playlist references both old and new stations', () async {
      final p = _provider();
      await p.importEntries(entries, playlistName: 'Imported');
      final playlist = p.playlists.single;

      expect(playlist.name, 'Imported');
      expect(playlist.stationIds, hasLength(2));
      expect(playlist.stationIds.first, 's1');
    });

    test('a file listing the same URL twice adds it once', () async {
      final p = _provider(stations: const []);
      final (added, _) = await p.importEntries(const [
        (name: 'A', url: 'https://live.example/a'),
        (name: 'A again', url: 'https://live.example/a'),
      ], playlistName: 'Dupes');

      expect(added, 1);
      expect(p.playlists.single.stationIds, hasLength(1));
    });

    test('no playlist is created when none is named', () async {
      final p = _provider();
      await p.importEntries(entries);

      expect(p.playlists, isEmpty);
      expect(p.stations, hasLength(3));
    });
  });

  group('startup state', () {
    test('busy covers both unlocking and loading', () {
      final p = _provider();

      p.setStartupPhase(StartupPhase.unlocking);
      expect(p.busy, isTrue);

      p.setStartupPhase(StartupPhase.loading);
      expect(p.busy, isTrue);

      p.setStartupPhase(StartupPhase.ready);
      expect(p.busy, isFalse);
    });

    test('setKeySaved notifies only on a real change', () {
      final p = _provider();
      var notifications = 0;
      p.addListener(() => notifications++);

      p.setKeySaved(true);
      p.setKeySaved(true);

      expect(notifications, 1);
    });
  });
}
