/// Tests for stationMatches, the Stations filter.
///
// Time-stamp: <Sunday 2026-10-25 10:00:00 +1100 Graham Williams>
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

import 'package:radiopod/models/cast.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/station_filter.dart';

const _radio = Station(
  id: 'r',
  name: 'ABC Classic',
  url: 'https://x.example/classic',
  description: 'Not searched for a station.',
);

const _podcast = Station(
  id: 'p',
  name: 'If You\'re Listening',
  url: 'https://x.example/feed.xml',
  isPodcast: true,
  description: 'The biggest story in world news.',
);

final _casts = [
  Cast(
    guid: 'g1',
    title: 'The Saudi city of NEOM',
    published: DateTime.utc(2026, 10, 1),
    audioUrl: 'https://x.example/1.mp3',
    description: 'A desert megaproject and what it says about power.',
  ),
];

void main() {
  test('an empty query matches everything', () {
    expect(stationMatches(_radio, const [], ''), isTrue);
  });

  test('a name matches, whatever the case', () {
    expect(stationMatches(_radio, const [], 'classic'), isTrue);
    expect(stationMatches(_podcast, _casts, 'listening'), isTrue);
  });

  test('a podcast matches on its description', () {
    expect(stationMatches(_podcast, _casts, 'world news'), isTrue);
  });

  test('a podcast matches on an episode title or its show notes', () {
    expect(stationMatches(_podcast, _casts, 'neom'), isTrue);
    expect(stationMatches(_podcast, _casts, 'megaproject'), isTrue);
  });

  test('a station matches on its name only', () {
    expect(stationMatches(_radio, const [], 'searched'), isFalse);
  });

  test('no match is no match', () {
    expect(stationMatches(_podcast, _casts, 'cricket'), isFalse);
  });

  group('playlistMatches', () {
    List<Cast> castsOf(String id) => id == 'p' ? _casts : const [];
    const both = [_radio, _podcast];

    test('a matching name shows every station, even none', () {
      expect(playlistMatches('Drive', both, castsOf, 'drive'), both);
      expect(playlistMatches('Drive', const [], castsOf, 'drive'), isEmpty);
    });

    test('else only the stations that match', () {
      expect(playlistMatches('Drive', both, castsOf, 'neom'), [_podcast]);
    });

    test('nothing matching hides the playlist', () {
      expect(playlistMatches('Drive', both, castsOf, 'cricket'), isNull);
    });
  });

  test('an episode matches on its title or show notes', () {
    final cast = _casts.single;

    expect(castMatches(cast, ''), isTrue);
    expect(castMatches(cast, 'neom'), isTrue);
    expect(castMatches(cast, 'megaproject'), isTrue);
    expect(castMatches(cast, 'cricket'), isFalse);
  });
}
