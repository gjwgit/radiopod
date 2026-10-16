/// Tests for Podcast Index request signing and result mapping.
///
// Time-stamp: <Friday 2026-10-16 06:00:00 +1100 Graham Williams>
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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/services/podcast_index.dart';

void main() {
  test('signs with sha1(key + secret + unix time)', () {
    final h = podcastIndexHeaders(
      'KEY',
      'SECRET',
      DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000, isUtc: true),
    );

    expect(h['X-Auth-Key'], 'KEY');
    expect(h['X-Auth-Date'], '1760000000');
    // Computed independently: hashlib.sha1(b'KEYSECRET1760000000').
    expect(h['Authorization'], '0567bdf913cbd2472696d5cc4d9d20601a4d5a4b');
    expect(h['User-Agent'], startsWith('RadioPod/'));
    // The secret itself never goes over the wire.
    expect(h.values.join(' '), isNot(contains('SECRET')));
  });

  group('podcastsFromSearch', () {
    String body(List<Map<String, Object?>> feeds) =>
        jsonEncode({'status': 'true', 'feeds': feeds});

    test('maps a feed to a podcast station', () {
      final p = podcastsFromSearch(
        body([
          {
            'id': 920666,
            'title': 'Future Tense',
            'url': 'https://www.abc.net.au/feeds/2883726/podcast.xml',
            'link': 'https://www.abc.net.au/listen/programs/futuretense/',
            'author': 'ABC Australia',
            'artwork': 'https://x.example/art.jpg',
            'image': 'https://x.example/img.jpg',
            'language': 'en',
            'categories': {'55': 'News', '59': 'Tech'},
          },
        ]),
      ).single;

      expect(p.isPodcast, isTrue);
      expect(p.name, 'Future Tense');
      expect(p.url, 'https://www.abc.net.au/feeds/2883726/podcast.xml');
      expect(p.author, 'ABC Australia');
      expect(p.favicon, 'https://x.example/art.jpg');
      expect(p.tags, ['News', 'Tech']);
    });

    test('skips dead feeds, untitled feeds and repeats', () {
      final p = podcastsFromSearch(
        body([
          {'title': 'Dead', 'url': 'https://x.example/dead', 'dead': 1},
          {'title': '', 'url': 'https://x.example/untitled'},
          {'title': 'One', 'url': 'https://x.example/one'},
          {'title': 'One again', 'url': 'https://x.example/one'},
        ]),
      );

      expect(p.map((s) => s.name), ['One']);
    });

    test(
      'falls back to image and owner when artwork and author are absent',
      () {
        final p = podcastsFromSearch(
          body([
            {
              'title': 'T',
              'url': 'https://x.example/t',
              'image': 'https://x.example/img.jpg',
              'ownerName': 'Owner',
            },
          ]),
        ).single;

        expect(p.favicon, 'https://x.example/img.jpg');
        expect(p.author, 'Owner');
      },
    );

    test('an answer with no feeds is empty, not an error', () {
      expect(podcastsFromSearch('{"status":"true","count":0}'), isEmpty);
      expect(podcastsFromSearch('[]'), isEmpty);
    });
  });
}
