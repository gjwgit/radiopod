/// Tests for M3U playlist parsing and writing.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/utils/m3u.dart';
import 'package:radiopod/utils/playlist_file.dart';

void main() {
  group('parseM3u', () {
    test('reads extended entries', () {
      final entries = parseM3u('''
#EXTM3U
#EXTINF:-1,ABC Classic
https://live.example/classic
#EXTINF:-1,Double J
https://live.example/doublej
''');

      expect(entries, hasLength(2));
      expect(entries[0].name, 'ABC Classic');
      expect(entries[0].url, 'https://live.example/classic');
      expect(entries[1].name, 'Double J');
    });

    test('falls back to the host for a plain URL list', () {
      final entries = parseM3u(
        'https://stream.example.org/live\nhttp://other.example/mp3\n',
      );

      expect(entries, hasLength(2));
      expect(entries[0].name, 'stream.example.org');
      expect(entries[1].name, 'other.example');
    });

    test('keeps only the text after the first comma', () {
      final entries = parseM3u(
        '#EXTINF:-1 tvg-logo="x.png",Jazz, Blues and More\n'
        'https://live.example/jazz\n',
      );

      expect(entries.single.name, 'Jazz, Blues and More');
    });

    test('ignores comments, blank lines and CRLF endings', () {
      final entries = parseM3u(
        '#EXTM3U\r\n\r\n#PLAYLIST:Mine\r\n'
        '#EXTINF:-1,Station\r\nhttps://live.example/s\r\n',
      );

      expect(entries, hasLength(1));
      expect(entries.single.url, 'https://live.example/s');
    });

    test('does not carry a name over to a later untitled entry', () {
      final entries = parseM3u(
        '#EXTINF:-1,Named\n'
        'https://live.example/a\n'
        'https://live.example/b\n',
      );

      expect(entries[0].name, 'Named');
      expect(entries[1].name, 'live.example');
    });

    test('an empty playlist yields no entries', () {
      expect(parseM3u('#EXTM3U\n'), isEmpty);
    });
  });

  group('writeM3u', () {
    test('round-trips through parseM3u', () {
      const entries = <PlaylistEntry>[
        (name: 'One', url: 'https://live.example/one'),
        (name: 'Two', url: 'http://live.example/two'),
      ];

      expect(parseM3u(writeM3u(entries)), entries);
    });

    test('starts with the EXTM3U header', () {
      expect(writeM3u(const []), '#EXTM3U\n');
    });

    test('flattens a newline in a station name', () {
      final out = writeM3u(const [
        (name: 'Two\nLines', url: 'https://live.example/x'),
      ]);

      expect(out, contains('#EXTINF:-1,Two Lines\n'));
      expect(parseM3u(out).single.name, 'Two Lines');
    });
  });
}
