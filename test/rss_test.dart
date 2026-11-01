/// Tests for reading podcast feeds, on feeds saved from the wild.
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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/utils/rss.dart';

String _fixture(String name) =>
    File('test/fixtures/feeds/$name.xml').readAsStringSync();

void main() {
  group('parseFeed on real feeds', () {
    test('NPR News Now: short hourly bulletins in seconds', () {
      final feed = parseFeed(_fixture('npr_news_now'));

      expect(feed.title, 'NPR News Now');
      expect(feed.author, 'NPR');
      expect(feed.image, startsWith('https://media.npr.org/'));
      expect(feed.casts, hasLength(3));

      final latest = feed.casts.first;
      expect(latest.guid, 'e8f5982b-6e15-47d1-a991-eadb80e2e8f5');
      expect(latest.duration, const Duration(seconds: 280));
      expect(latest.published, DateTime.utc(2026, 10, 16, 4, 9, 43));
      // The &amp; in the enclosure attribute arrives decoded.
      expect(latest.audioUrl, contains('&awEpisodeId='));
      expect(latest.audioUrl, isNot(contains('&amp;')));
    });

    test('ABC Future Tense: +1100 dates and h:mm:ss durations', () {
      final feed = parseFeed(_fixture('abc_future_tense'));

      expect(feed.title, 'Future Tense');
      expect(feed.author, 'ABC Australia');
      expect(feed.image, contains('FutureTense_3000x3000.jpg'));

      final latest = feed.casts.first;
      expect(latest.title, 'The danger of generational labelling');
      // 09:30 in Sydney's summer is 22:30 UTC the day before.
      expect(latest.published, DateTime.utc(2026, 1, 15, 22, 30));
      expect(latest.duration, const Duration(minutes: 29, seconds: 6));
      // HTML show notes come out as plain text.
      expect(latest.description, startsWith('Terms like "Gen Z"'));
      expect(latest.description, isNot(contains('<p>')));
    });

    test('The Daily: newest first, itunes:summary preferred', () {
      final feed = parseFeed(_fixture('nyt_the_daily'));

      expect(feed.title, 'The Daily');
      expect(feed.casts.map((c) => c.published), [
        DateTime.utc(2026, 10, 15, 9, 52, 12),
        DateTime.utc(2026, 10, 14, 9, 51, 54),
        DateTime.utc(2026, 10, 13, 9, 45),
      ]);
      expect(
        feed.casts.first.duration,
        const Duration(minutes: 33, seconds: 50),
      );
      expect(feed.casts.every((c) => c.description.length <= 401), isTrue);
    });
  });

  group('parseFeed edge cases', () {
    String feed(String items) =>
        '<?xml version="1.0"?><rss version="2.0" '
        'xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">'
        '<channel><title>T</title>$items</channel></rss>';

    test('castNotes gives the whole text, paragraphs kept', () {
      final xml = feed(
        '<item><guid>g1</guid><title>A</title>'
        '<description>Short</description>'
        '<content:encoded xmlns:content="http://purl.org/rss/1.0/modules/content/">'
        '&lt;p&gt;First part.&lt;/p&gt;&lt;p&gt;Second part.&lt;/p&gt;'
        '</content:encoded>'
        '<enclosure url="https://x.example/a.mp3" type="audio/mpeg"/></item>'
        '<item><title>B</title><description>Bee</description>'
        '<enclosure url="https://x.example/b.mp3" type="audio/mpeg"/></item>',
      );

      expect(castNotes(xml, 'g1'), 'First part.\n\nSecond part.');
      // No guid: matched on the audio URL, as parseFeed does.
      expect(castNotes(xml, 'https://x.example/b.mp3'), 'Bee');
      expect(castNotes(xml, 'gone'), isNull);
    });

    test('the channel description is kept as plain text', () {
      final about = parseFeed(
        '<?xml version="1.0"?><rss version="2.0" '
        'xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">'
        '<channel><title>T</title>'
        '<description>&lt;p&gt;The world, &lt;b&gt;explained&lt;/b&gt;.'
        '&lt;/p&gt;</description></channel></rss>',
      ).description;

      expect(about, 'The world, explained.');
    });

    test('itunes:summary is preferred, and none at all is null', () {
      final summary = parseFeed(
        '<?xml version="1.0"?><rss version="2.0" '
        'xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">'
        '<channel><title>T</title><description>Short</description>'
        '<itunes:summary>Longer</itunes:summary></channel></rss>',
      ).description;

      expect(summary, 'Longer');
      expect(parseFeed(feed('')).description, isNull);
    });

    test('a missing guid falls back to the audio URL', () {
      final casts = parseFeed(
        feed(
          '<item><title>A</title>'
          '<enclosure url="https://x.example/a.mp3" type="audio/mpeg"/></item>',
        ),
      ).casts;

      expect(casts.single.guid, 'https://x.example/a.mp3');
    });

    test('items without audio are not casts', () {
      final casts = parseFeed(
        feed(
          '<item><title>Blog post</title></item>'
          '<item><title>Video</title>'
          '<enclosure url="https://x.example/v.mp4" type="video/mp4"/></item>'
          '<item><title>Untyped</title>'
          '<enclosure url="https://x.example/u.m4a?x=1"/></item>',
        ),
      ).casts;

      expect(casts.map((c) => c.title), ['Untyped']);
    });

    test('an unparseable date sorts last instead of failing', () {
      final casts = parseFeed(
        feed(
          '<item><title>Old</title><pubDate>sometime</pubDate>'
          '<enclosure url="https://x.example/o.mp3" type="audio/mpeg"/></item>'
          '<item><title>New</title>'
          '<pubDate>Mon, 12 Oct 2026 10:00:00 GMT</pubDate>'
          '<enclosure url="https://x.example/n.mp3" type="audio/mpeg"/></item>',
        ),
      ).casts;

      expect(casts.map((c) => c.title), ['New', 'Old']);
    });

    test('not a feed throws FormatException', () {
      expect(() => parseFeed('<html><body/></html>'), throwsFormatException);
      expect(() => parseFeed('not xml at all <'), throwsFormatException);
    });
  });

  group('parseItunesDuration', () {
    test('seconds, mm:ss and hh:mm:ss', () {
      expect(parseItunesDuration('280'), const Duration(seconds: 280));
      expect(
        parseItunesDuration('29:06'),
        const Duration(minutes: 29, seconds: 6),
      );
      expect(
        parseItunesDuration('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('rubbish and zero are unknown', () {
      expect(parseItunesDuration(''), isNull);
      expect(parseItunesDuration('about an hour'), isNull);
      expect(parseItunesDuration('0'), isNull);
      expect(parseItunesDuration('1:2:3:4'), isNull);
    });
  });

  group('parseRfc822', () {
    test('numeric and named zones', () {
      expect(
        parseRfc822('Wed, 15 Oct 2026 19:00:00 -0400'),
        DateTime.utc(2026, 10, 15, 23),
      );
      expect(
        parseRfc822('15 Oct 2026 19:00 EST'),
        DateTime.utc(2026, 10, 16, 0),
      );
    });

    test('full month names, two-digit years and ISO dates', () {
      expect(
        parseRfc822('Thu, 1 October 26 08:00:00 GMT'),
        DateTime.utc(2026, 10, 1, 8),
      );
      expect(parseRfc822('2026-10-01T08:00:00Z'), DateTime.utc(2026, 10, 1, 8));
      expect(parseRfc822('never'), isNull);
    });
  });

  group('plainText', () {
    test('drops tags and decodes entities', () {
      expect(
        plainText('<p>Fish &amp; chips&nbsp;&#8212; <b>hot</b></p>', limit: 99),
        'Fish & chips — hot',
      );
    });

    test('cuts long text at a word', () {
      final s = plainText('one two three four five six', limit: 15);

      expect(s, 'one two three…');
    });
  });
}
