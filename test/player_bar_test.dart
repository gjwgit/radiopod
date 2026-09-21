/// Widget tests for the now-playing bar's second line.
///
/// PlayerBar reads the live media session, which needs a running audio
/// service, so these exercise the same MediaItem shape the handler
/// publishes through the presentation logic rather than the whole widget.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

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
