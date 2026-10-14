/// Tests for shaping Radio-Browser search results.
///
// Time-stamp: <Tuesday 2026-09-22 06:00:00 +1000 Graham Williams>
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

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/radio_browser.dart';

/// The real shape of a Radio-Browser answer for "ABC News Radio": several
/// separate records, with different names and logos, all resolving to one
/// Icecast address, plus an HLS entry and a genuinely different stream.

const _icecast = 'http://abc.streamguys1.com/live/newsradio/icecast.audio';
const _mp3 = 'http://live-radio01.mediahubaustralia.com/PBW/mp3/';
const _hls = 'https://mediaserviceslive.akamaized.net/hls/live/newsradio.m3u8';

Station _station(String name, String url, {String? favicon}) =>
    Station(id: name, name: name, url: url, favicon: favicon);

Map<String, dynamic> _record(String name, int? clicks) => {
  'name': name,
  'clickcount': clicks,
};

void main() {
  group('byClickCount', () {
    test('interleaves a Location search\'s country and state answers', () {
      // Each answer arrives most-clicked first; appended one after the
      // other, a popular state match would sit below every country match.

      final country = [_record('AU 1', 900), _record('AU 2', 100)];
      final state = [_record('VIC 1', 500), _record('VIC 2', 50)];

      expect(byClickCount([...country, ...state]).map((r) => r['name']), [
        'AU 1',
        'VIC 1',
        'AU 2',
        'VIC 2',
      ]);
    });

    test('keeps arrival order among equal counts', () {
      final records = [
        _record('a', 10),
        _record('b', 10),
        _record('c', 10),
        _record('d', 10),
      ];

      expect(byClickCount(records).map((r) => r['name']), ['a', 'b', 'c', 'd']);
    });

    test('a missing count sorts as zero rather than failing', () {
      final records = [_record('none', null), _record('some', 3)];

      expect(byClickCount(records).map((r) => r['name']), ['some', 'none']);
    });
  });

  test('Location keeps its keywords off the API, the others name a field', () {
    expect(SearchField.location.parameter, isNull);
    expect(SearchField.name.parameter, 'name');
    expect(SearchField.tag.parameter, 'tag');
  });

  group('uniqueByUrl', () {
    test('collapses records that share a stream address', () {
      // The bug this fixes: four rows, one tap, four ticks. They were the
      // same station all along, and the library matches on URL.

      final results = uniqueByUrl([
        _station('ABC News Radio', _icecast, favicon: 'a.png'),
        _station('ABC News Radio', _icecast, favicon: 'b.png'),
        _station('ABC News Radio', _icecast, favicon: 'c.png'),
        _station('ABC News Radio MP3', _mp3),
      ]);

      expect(results, hasLength(2));
      expect(results.map((s) => s.url), [_icecast, _mp3]);
    });

    test('keeps the first record of each stream', () {
      // After the ordering in search() that is the most listened-to entry,
      // which tends to carry the better name and logo.

      final results = uniqueByUrl([
        _station('ABC News Radio', _icecast, favicon: 'best.png'),
        _station('abc news', _icecast, favicon: 'worse.png'),
      ]);

      expect(results.single.name, 'ABC News Radio');
      expect(results.single.favicon, 'best.png');
    });

    test('leaves genuinely different streams alone', () {
      final results = uniqueByUrl([
        _station('ABC News Radio', _icecast),
        _station('ABC News Radio', _hls),
      ]);

      expect(results, hasLength(2));
    });

    test('preserves order', () {
      final results = uniqueByUrl([
        _station('c', 'https://live.example/c'),
        _station('a', 'https://live.example/a'),
        _station('c again', 'https://live.example/c'),
        _station('b', 'https://live.example/b'),
      ]);

      expect(results.map((s) => s.name), ['c', 'a', 'b']);
    });

    test('an empty result set stays empty', () {
      expect(uniqueByUrl(const []), isEmpty);
    });

    test('a URL differing only by case is a different stream', () {
      // Deliberate: the key must match the library's own saved-station check
      // exactly, and that compares URLs verbatim. Normalising here but not
      // there would bring the duplicate ticks straight back.

      final results = uniqueByUrl([
        _station('one', 'https://live.example/Stream'),
        _station('two', 'https://live.example/stream'),
      ]);

      expect(results, hasLength(2));
    });
  });
}
