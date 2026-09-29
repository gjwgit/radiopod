/// Tests for playlist format detection and dispatch.
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

import 'package:radiopod/screens/transfer_widgets/playlist_file_export.dart';
import 'package:radiopod/utils/playlist_file.dart';

void main() {
  group('detectFormat', () {
    test('trusts the file extension', () {
      expect(detectFormat('mine.pls', ''), PlaylistFormat.pls);
      expect(detectFormat('mine.m3u', ''), PlaylistFormat.m3u);
      expect(detectFormat('MINE.M3U8', ''), PlaylistFormat.m3u);
    });

    test('falls back to the content for an unknown extension', () {
      expect(
        detectFormat('mine.txt', '  [PlayList]\nFile1=x\n'),
        PlaylistFormat.pls,
      );
      expect(detectFormat('mine', '#EXTM3U\n'), PlaylistFormat.m3u);
      expect(detectFormat('mine', 'https://a.example/'), PlaylistFormat.m3u);
    });
  });

  group('parsePlaylist and writePlaylist', () {
    const entries = <PlaylistEntry>[
      (name: 'One', url: 'https://live.example/one'),
    ];

    test('dispatch to each format and round-trip', () {
      for (final format in PlaylistFormat.values) {
        final text = writePlaylist(entries, format);
        expect(parsePlaylist(text, format), entries, reason: format.label);
      }
    });
  });

  group('nameFromUrl', () {
    test('uses the host', () {
      expect(
        nameFromUrl('https://live.example.org/stream'),
        'live.example.org',
      );
    });

    test('falls back to the whole string when there is no host', () {
      expect(nameFromUrl('not a url'), 'not a url');
    });
  });

  group('safeFileName', () {
    test('replaces path separators and punctuation', () {
      expect(safeFileName('Drive / Work'), 'Drive___Work');
      expect(safeFileName('Jazz: late night'), 'Jazz__late_night');
    });

    test('collapses whitespace and trims', () {
      expect(safeFileName('  Morning   drive '), 'Morning_drive');
    });

    test('falls back to the app name when nothing is left', () {
      expect(safeFileName('   '), 'radiopod');
    });
  });
}
