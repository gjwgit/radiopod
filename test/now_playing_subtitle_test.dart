/// Tests for the second line of a station row while it is on air.
///
/// The media item is what carries that line to every surface — the station
/// row, the Android notification and the car — so these exercise the shape
/// the handler publishes rather than any one widget.
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
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/browse_tree.dart';

const _station = Station(
  id: 's1',
  name: 'LOVE RADIO Only Love Songs 70s80s90s',
  url: 'https://live.example/love',
  country: 'The United States Of America',
  language: 'english',
  codec: 'AAC+',
  bitrate: 192,
);

void main() {
  group('now-playing subtitle', () {
    test('falls back to station details before any track is announced', () {
      final item = stationMediaItem(_station, browseAllStationsId);

      expect(
        item.artist,
        'The United States Of America · english · AAC+ · 192 kbps',
      );
      expect(item.extras?['track'], isNull);
    });

    test('a track replaces the station details', () {
      final item = stationMediaItem(
        _station,
        browseAllStationsId,
        track: 'Chris Rea - On The Beach',
      );

      expect(item.artist, 'Chris Rea - On The Beach');
      expect(item.extras?['track'], 'Chris Rea - On The Beach');
    });

    test('the station name stays on the first line either way', () {
      final without = stationMediaItem(_station, browseAllStationsId);
      final with_ = stationMediaItem(
        _station,
        browseAllStationsId,
        track: 'Chris Rea - On The Beach',
      );

      expect(without.title, _station.name);
      expect(with_.title, _station.name);
    });

    test('extras still carry the station id for list highlighting', () {
      final item = stationMediaItem(
        _station,
        browseAllStationsId,
        track: 'Anything',
      );

      expect(item.extras?['stationId'], 's1');
      expect(item.album, appName);
    });
  });
}
