/// Tests for the media item while live captions are showing.
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
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/browse_tree.dart';

const _station = Station(
  id: 's1',
  name: 'ABC NewsRadio',
  url: 'https://live.example/news',
  country: 'Australia',
  codec: 'AAC+',
  bitrate: 64,
);

void main() {
  group('captioned media item', () {
    test('without a caption the station keeps the title', () {
      final item = stationMediaItem(
        _station,
        browseAllStationsId,
        track: 'The World Today',
      );

      expect(item.title, 'ABC NewsRadio');
      expect(item.artist, 'The World Today');
      expect(item.album, appName);
      expect(item.extras?['caption'], isNull);
    });

    test('a caption takes the title; station and programme the album', () {
      final item = stationMediaItem(
        _station,
        browseAllStationsId,
        track: 'The World Today',
        caption: 'Tokyo has recorded thirty four days of rain',
      );

      expect(item.title, 'Tokyo has recorded thirty four days of rain');
      expect(item.album, 'ABC NewsRadio · The World Today');
      expect(item.artist, isNull);
      expect(item.extras?['caption'], item.title);
    });

    test('with no programme announced the album is the station alone', () {
      final item = stationMediaItem(
        _station,
        browseAllStationsId,
        caption: 'Good morning',
      );

      expect(item.album, 'ABC NewsRadio');
    });

    test('the row still finds its station and song while captioned', () {
      final item = stationMediaItem(
        _station,
        'playlist:p1',
        track: 'The World Today',
        caption: 'Good morning',
      );

      expect(item.id, 'playlist:p1/s1');
      expect(item.extras?['stationId'], 's1');
      expect(item.extras?['track'], 'The World Today');
    });
  });
}
