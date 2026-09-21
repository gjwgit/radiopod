/// Tests for the Android Auto browse tree.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/browse_tree.dart';

const _stations = [
  Station(id: 's1', name: 'Zulu FM', url: 'https://live.example/z'),
  Station(id: 's2', name: 'Alpha FM', url: 'https://live.example/a'),
  Station(id: 's3', name: 'Bravo FM', url: 'https://live.example/b'),
];

const _playlists = [
  Playlist(id: 'p1', name: 'Drive', stationIds: ['s3', 's1']),
  Playlist(id: 'p2', name: 'Empty'),
];

void main() {
  group('station media ids', () {
    test('round-trip through split', () {
      final id = stationMediaId('${browsePlaylistPrefix}p1', 's3');
      final parts = splitStationMediaId(id);

      expect(parts?.parentId, '${browsePlaylistPrefix}p1');
      expect(parts?.stationId, 's3');
    });

    test('a folder id has no station in it', () {
      expect(splitStationMediaId(browseRootId), isNull);
      expect(splitStationMediaId(browseAllStationsId), isNull);
    });

    test('a trailing separator is not a station id', () {
      expect(splitStationMediaId('all_stations/'), isNull);
    });
  });

  group('browseRoot', () {
    test('lists playlists first, then All Stations', () {
      final root = browseRoot(_playlists);

      expect(root.map((m) => m.title), ['Drive', 'Empty', 'All Stations']);
      expect(root.every((m) => m.playable == false), isTrue);
    });

    test('counts the stations in each playlist', () {
      final root = browseRoot(_playlists);

      expect(root[0].displaySubtitle, '2 stations');
      expect(root[1].displaySubtitle, '0 stations');
    });

    test('an empty library still offers All Stations', () {
      expect(browseRoot(const []).single.id, browseAllStationsId);
    });
  });

  group('browseChildren', () {
    test('the root returns the root listing', () {
      expect(
        browseChildren(browseRootId, _stations, _playlists).map((m) => m.title),
        browseRoot(_playlists).map((m) => m.title),
      );
    });

    test('All Stations is sorted by name', () {
      final children = browseChildren(
        browseAllStationsId,
        _stations,
        _playlists,
      );

      expect(children.map((m) => m.title), ['Alpha FM', 'Bravo FM', 'Zulu FM']);
      expect(children.every((m) => m.playable == true), isTrue);
    });

    test('a playlist keeps its own order', () {
      final children = browseChildren(
        '${browsePlaylistPrefix}p1',
        _stations,
        _playlists,
      );

      expect(children.map((m) => m.title), ['Bravo FM', 'Zulu FM']);
    });

    test('a station deleted from the library is skipped', () {
      const playlists = [
        Playlist(id: 'p1', name: 'Drive', stationIds: ['s1', 'gone']),
      ];
      final children = browseChildren(
        '${browsePlaylistPrefix}p1',
        _stations,
        playlists,
      );

      expect(children.map((m) => m.title), ['Zulu FM']);
    });

    test('an unknown folder is empty rather than an error', () {
      expect(browseChildren('nonsense', _stations, _playlists), isEmpty);
      expect(
        browseChildren('${browsePlaylistPrefix}gone', _stations, _playlists),
        isEmpty,
      );
    });
  });

  group('stationMediaItem', () {
    test('carries the station id in extras for the UI to match on', () {
      final item = stationMediaItem(_stations.first, browseAllStationsId);

      expect(item.extras?['stationId'], 's1');
      expect(item.isLive, isTrue);
      expect(item.album, appName);
    });

    test('rejects a favicon that is not http(s)', () {
      const station = Station(
        id: 's9',
        name: 'Odd',
        url: 'https://live.example/o',
        favicon: 'javascript:alert(1)',
      );

      expect(stationMediaItem(station, browseAllStationsId).artUri, isNull);
    });

    test('accepts an https favicon', () {
      const station = Station(
        id: 's9',
        name: 'Logo',
        url: 'https://live.example/o',
        favicon: 'https://live.example/logo.png',
      );

      expect(
        stationMediaItem(station, browseAllStationsId).artUri.toString(),
        'https://live.example/logo.png',
      );
    });
  });
}
