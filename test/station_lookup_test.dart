/// Tests for filling in a hand-added station from Radio-Browser.
///
// Time-stamp: <Wednesday 2026-10-14 10:00:00 +1100 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
//
/// Authors: Graham Williams

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/station_lookup.dart';

/// As typed into New station, then marked to reconnect.

const _typed = Station(
  id: 'local-1',
  name: 'RN',
  url: 'https://streaming.abc-cdn.net.au/audio/hls/rnnsw.m3u8?source=web',
  icon: 'iVBORw0KGgo=',
  reconnectOnEnd: true,
  isHls: true,
);

/// Radio-Browser's record for the same address.

const _found = Station(
  id: 'fresh-uuid',
  name: 'ABC Radio National (NSW)',
  url: 'https://streaming.abc-cdn.net.au/audio/hls/rnnsw.m3u8?source=web',
  country: 'Australia',
  language: 'english',
  codec: 'AAC',
  bitrate: 115,
  stationUuid: '84b9e367-705d-4be3-a0c1-61c9ec48a449',
  isHls: true,
);

void main() {
  final merged = withRadioBrowserDetails(_typed, _found);

  group('withRadioBrowserDetails keeps what the listener entered', () {
    test('the local id, so playlists still hold the station', () {
      expect(merged.id, 'local-1');
    });

    test('the name they typed', () {
      expect(merged.name, 'RN');
    });

    test('the address, the picture and the reconnect setting', () {
      expect(merged.url, _typed.url);
      expect(merged.icon, _typed.icon);
      expect(merged.reconnectOnEnd, isTrue);
    });
  });

  group('withRadioBrowserDetails takes the facts from the record', () {
    test('so the subtitle reads in full', () {
      expect(
        merged.subtitle,
        'Radio · Australia · english · AAC · 115 kbps · HLS',
      );
    });

    test('and the Radio-Browser id, so Refresh works from now on', () {
      expect(merged.stationUuid, _found.stationUuid);
    });
  });
}
