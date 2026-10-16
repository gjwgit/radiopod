/// OPML tests — read and write podcast subscription lists.
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

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/utils/opml.dart';

// A trimmed export in the shape Pocket Casts and AntennaPod write, with the
// quirks found in the wild: a folder, a lower-case attribute, a feed listed
// twice, a missing text, a non-web feed and an escaped ampersand.

const _wild = '''<?xml version="1.0" encoding="utf-8"?>
<opml version="1.0">
  <head><title>Pocket Casts Feeds</title></head>
  <body>
    <outline text="feeds">
      <outline type="rss" text="Future Tense"
        xmlUrl="https://www.abc.net.au/feeds/2883726/podcast.xml"
        htmlUrl="https://www.abc.net.au/listen/programs/futuretense"/>
      <outline type="rss" text="Up First &amp; More"
        xmlurl="https://feeds.npr.org/510318/podcast.xml"/>
    </outline>
    <outline type="rss" text="Future Tense again"
      xmlUrl="https://www.abc.net.au/feeds/2883726/podcast.xml"/>
    <outline type="rss" title="Only a title" xmlUrl="https://a.example/f"/>
    <outline type="rss" xmlUrl="https://b.example/feed.xml"/>
    <outline type="rss" text="Local" xmlUrl="file:///home/me/feed.xml"/>
    <outline type="rss" text="Bad site" xmlUrl="https://c.example/f"
      htmlUrl="javascript:alert(1)"/>
  </body>
</opml>''';

void main() {
  group('parseOpml', () {
    final feeds = parseOpml(_wild);

    test('reads feeds at any depth, in file order, each once', () {
      expect(feeds.map((f) => f.url), [
        'https://www.abc.net.au/feeds/2883726/podcast.xml',
        'https://feeds.npr.org/510318/podcast.xml',
        'https://a.example/f',
        'https://b.example/feed.xml',
        'https://c.example/f',
      ]);
    });

    test('keeps the first title of a feed listed twice', () {
      expect(feeds.first.title, 'Future Tense');
      expect(
        feeds.first.homepage,
        'https://www.abc.net.au/listen/programs/futuretense',
      );
    });

    test('matches xmlUrl without regard to case and unescapes', () {
      expect(feeds[1].title, 'Up First & More');
      expect(feeds[1].homepage, isNull);
    });

    test('falls back from text to title to the host', () {
      expect(feeds[2].title, 'Only a title');
      expect(feeds[3].title, 'b.example');
    });

    test('drops a web site that is not http or https', () {
      expect(feeds[4].homepage, isNull);
    });

    test('an OPML with no feeds is empty, not an error', () {
      expect(parseOpml('<opml version="2.0"><body/></opml>'), isEmpty);
    });

    test('rejects what is not OPML', () {
      expect(() => parseOpml('<rss/>'), throwsFormatException);
      expect(() => parseOpml('#EXTM3U'), throwsFormatException);
    });
  });

  group('writeOpml', () {
    const feeds = [
      (
        title: 'Tom & Jerry\'s "Show" <live>',
        url: 'https://x.example/feed?a=1&b=2',
        homepage: 'https://x.example/',
      ),
      (title: 'Ünïcode Cast', url: 'https://y.example/f', homepage: null),
    ];

    test('round-trips titles, feeds and sites, awkward characters too', () {
      final back = parseOpml(writeOpml(feeds));

      expect(back, feeds);
    });

    test('writes OPML 2.0 with text and title on each outline', () {
      final xml = writeOpml(feeds, title: 'RadioPod podcasts');

      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<opml version="2.0">'));
      expect(xml, contains('<title>RadioPod podcasts</title>'));
      expect(xml, contains('type="rss"'));
      expect(xml, contains('title="Ünïcode Cast"'));
      expect(xml, isNot(contains('htmlUrl="null"')));
    });
  });
}
