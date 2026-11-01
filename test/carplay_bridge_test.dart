/// Tests for the library payload sent to the CarPlay scene.
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
/// Authors: Tony Chen

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/carplay_bridge.dart';
import 'package:radiopod/services/station_logo_cache.dart';

const _stations = [
  Station(id: 's1', name: 'Zulu FM', url: 'https://live.example/z'),
  Station(
    id: 's2',
    name: 'Alpha FM',
    url: 'https://live.example/a',
    favicon: 'https://live.example/a.png',
  ),
];

const _playlists = [
  Playlist(id: 'p1', name: 'Drive', stationIds: ['s2', 'gone', 's1']),
  Playlist(id: 'p2', name: 'Empty'),
];

void main() {
  final library = carPlayLibrary(_stations, _playlists);
  final stations = library['stations']! as List;
  final playlists = library['playlists']! as List;

  test('the Stations tab keeps the library order', () {
    expect(stations.map((s) => s['title']), ['Zulu FM', 'Alpha FM']);
    expect(stations.first['mediaId'], '$browseAllStationsId/s1');
    expect(stations.first['stationId'], 's1');
  });

  // 20261018 gjw The kept copy, never the logo's own address, which the
  // car would fetch itself (StationLogoCache).

  test('station logos are passed on as the kept copy only', () {
    expect(stations.last['artUri'], isNull);

    StationLogoCache.debugSetKept('https://live.example/a.png', '/tmp/icons');
    addTearDown(StationLogoCache.resetForTest);
    final kept = carPlayLibrary(_stations, _playlists)['stations']! as List;

    // Compared as a path, not a file:// string, which lychee would check as
    // a link that does not exist.

    final art = Uri.parse(kept.last['artUri'] as String);

    expect(kept.first['artUri'], isNull);
    expect(art.isScheme('file'), isTrue);
    expect(art.toFilePath(), startsWith('/tmp/icons/logo_'));
  });

  test('the Playlists tab lists every playlist, empty ones included', () {
    expect(playlists.map((p) => p['title']), ['Drive', 'Empty']);
    expect(playlists.last['stations'], isEmpty);
  });

  test('a playlist keeps its own order and drops deleted stations', () {
    final drive = playlists.first['stations'] as List;

    expect(drive.map((s) => s['stationId']), ['s2', 's1']);
    expect(drive.first['mediaId'], '${browsePlaylistPrefix}p1/s2');
  });
}
