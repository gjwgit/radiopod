/// Tests for PLS playlist parsing and writing.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/utils/playlist_file.dart';
import 'package:radiopod/utils/pls.dart';

void main() {
  group('parsePls', () {
    test('reads a standard playlist', () {
      final entries = parsePls('''
[playlist]
NumberOfEntries=2
File1=https://live.example/one
Title1=Station One
Length1=-1
File2=https://live.example/two
Title2=Station Two
Length2=-1
Version=2
''');

      expect(entries, hasLength(2));
      expect(entries[0].name, 'Station One');
      expect(entries[1].url, 'https://live.example/two');
    });

    test('orders by index, not by position in the file', () {
      final entries = parsePls(
        '[playlist]\n'
        'File2=https://live.example/two\nTitle2=Two\n'
        'File1=https://live.example/one\nTitle1=One\n',
      );

      expect(entries.map((e) => e.name), ['One', 'Two']);
    });

    test('tolerates non-contiguous indices', () {
      final entries = parsePls(
        '[playlist]\nFile1=https://a.example/\nFile7=https://b.example/\n',
      );

      expect(entries.map((e) => e.url), [
        'https://a.example/',
        'https://b.example/',
      ]);
    });

    test('matches keys case-insensitively', () {
      final entries = parsePls(
        '[playlist]\nfile1=https://live.example/x\ntitle1=Lower\n',
      );

      expect(entries.single.name, 'Lower');
    });

    test('falls back to the host when a title is missing', () {
      final entries = parsePls('[playlist]\nFile1=https://live.example/x\n');

      expect(entries.single.name, 'live.example');
    });

    test('ignores a stale NumberOfEntries', () {
      final entries = parsePls(
        '[playlist]\nNumberOfEntries=9\nFile1=https://live.example/x\n',
      );

      expect(entries, hasLength(1));
    });

    test('a title with no matching file is dropped', () {
      expect(parsePls('[playlist]\nTitle1=Orphan\n'), isEmpty);
    });
  });

  group('writePls', () {
    test('round-trips through parsePls', () {
      const entries = <PlaylistEntry>[
        (name: 'One', url: 'https://live.example/one'),
        (name: 'Two', url: 'http://live.example/two'),
      ];

      expect(parsePls(writePls(entries)), entries);
    });

    test('numbers entries from one and reports the count', () {
      final out = writePls(const [
        (name: 'A', url: 'https://a.example/'),
        (name: 'B', url: 'https://b.example/'),
      ]);

      expect(out, contains('File1=https://a.example/'));
      expect(out, contains('Title2=B'));
      expect(out, contains('NumberOfEntries=2'));
      expect(out, contains('Version=2'));
    });
  });
}
