/// Tests for the Android Auto browse tree.
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

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/browse_tree.dart';
import 'package:radiopod/services/station_icon_cache.dart';

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
    test('lists All Stations first, then the playlists', () {
      // Android Auto turns these into tabs and opens the first, so All
      // Stations leading means the driver lands on the station list rather
      // than having to drill into a folder.

      final root = browseRoot(_playlists);

      expect(root.map((m) => m.title), ['All Stations', 'Drive', 'Empty']);
      expect(root.every((m) => m.playable == false), isTrue);
    });

    test('counts the stations in each playlist', () {
      final root = browseRoot(_playlists);

      expect(root[1].displaySubtitle, '2 stations');
      expect(root[2].displaySubtitle, '0 stations');
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

    test('All Stations keeps library order, not alphabetical', () {
      final children = browseChildren(
        browseAllStationsId,
        _stations,
        _playlists,
      );

      // _stations is deliberately not in alphabetical order, so this would
      // fail if the browse tree re-sorted and threw away the arrangement
      // the user made by dragging on the Stations screen.

      expect(children.map((m) => m.title), ['Zulu FM', 'Alpha FM', 'Bravo FM']);
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

    // 20261005 gjw A picture the user chose beats the station's own logo.
    //
    // Station.icon is base64 in the Pod data and there is nothing for a head
    // unit to fetch, so these were invisible in the car while the app showed
    // them. StationIconCache writes the icon out and the artUri points at
    // that file. These tests drive the cache through its test seam rather
    // than touching the filesystem.

    test('a browse row keeps the station logo, not the chosen icon', () {
      StationIconCache.resetForTest();
      StationIconCache.debugSetPath('s1', '/tmp/station_icons/s1.png');
      addTearDown(StationIconCache.resetForTest);

      const station = Station(
        id: 's1',
        name: 'Alpha FM',
        url: 'https://live.example/a',
        favicon: 'https://logo.example/alpha.png',
      );
      final item = stationMediaItem(station, browseAllStationsId);

      // Android Auto fetches a browse row's icon in ITS process and cannot
      // read our files, so the row must carry the fetchable logo. Preferring
      // the chosen icon here left the car showing nothing at all.

      expect(item.artUri.toString(), 'https://logo.example/alpha.png');

      // The now playing item is loaded in our process, so it gets the icon.

      expect(sessionArtUri(station)?.toFilePath(), '/tmp/station_icons/s1.png');
    });

    test('the station logo is used when there is no chosen icon', () {
      StationIconCache.resetForTest();

      const station = Station(
        id: 's1',
        name: 'Alpha FM',
        url: 'https://live.example/a',
        favicon: 'https://logo.example/alpha.png',
      );

      expect(
        stationMediaItem(station, browseAllStationsId).artUri.toString(),
        'https://logo.example/alpha.png',
      );
    });

    test('the subtitle is the station details when no track is known', () {
      const station = Station(
        id: 's1',
        name: 'Alpha FM',
        url: 'https://live.example/a',
        country: 'Australia',
        codec: 'MP3',
      );
      final item = stationMediaItem(station, browseAllStationsId);

      expect(item.artist, 'Australia · MP3');
      expect(item.extras?['track'], isNull);
    });

    test('a known track takes the subtitle slot', () {
      const station = Station(
        id: 's1',
        name: 'Alpha FM',
        url: 'https://live.example/a',
        country: 'Australia',
        codec: 'MP3',
      );
      final item = stationMediaItem(
        station,
        browseAllStationsId,
        track: 'Nina Simone - Feeling Good',
      );

      expect(item.artist, 'Nina Simone - Feeling Good');
      expect(item.extras?['track'], 'Nina Simone - Feeling Good');
      expect(item.title, 'Alpha FM');
    });

    test('a track shows even for a station with no details', () {
      final item = stationMediaItem(
        _stations.first,
        browseAllStationsId,
        track: 'Some Song',
      );

      expect(item.artist, 'Some Song');
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
