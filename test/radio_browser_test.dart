/// Tests for shaping Radio-Browser search results.
///
// Time-stamp: <Tuesday 2026-09-22 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

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

void main() {
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
