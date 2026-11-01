/// RSS — read a podcast feed into a title, artwork and casts.
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

import 'package:xml/xml.dart';

import 'package:radiopod/models/cast.dart';

/// What a podcast feed says about itself and its episodes.

typedef PodcastFeed = ({
  String title,
  String? author,
  String? image,
  String? homepage,
  String? description,
  List<Cast> casts,
});

/// The longest description kept, in characters. See [Cast.description].

const castDescriptionLength = 400;

/// The longest podcast description kept, in characters, as long as the one
/// Search shows.

const podcastDescriptionLength = 1200;

/// Parse an RSS 2.0 podcast feed, newest cast first.
///
/// 20261016 gjw Written against the feeds actually found in the wild rather
/// than the specification: the iTunes tags are read wherever present, a
/// missing `<guid>` falls back to the audio URL, an item with no audio
/// enclosure is skipped (it is a blog post, not an episode), and a date that
/// will not parse sorts last rather than failing the feed. Pure, so it can be
/// tested on saved feeds without a network.
///
/// Throws [FormatException] when [xml] is not an RSS feed at all.

PodcastFeed parseFeed(String xml) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xml);
  } on XmlException catch (e) {
    throw FormatException('Not a podcast feed: ${e.message}');
  }

  final channel = doc.findAllElements('channel').firstOrNull;
  if (channel == null) throw const FormatException('Not a podcast feed.');

  final casts = [for (final item in channel.findElements('item')) ?_cast(item)]
    ..sort((a, b) => b.published.compareTo(a.published));

  return (
    title: _text(channel, 'title') ?? 'Podcast',
    author: _text(channel, 'itunes:author') ?? _text(channel, 'author'),
    image:
        _attr(channel, 'itunes:image', 'href') ??
        channel.getElement('image')?.getElement('url')?.innerText.trim(),
    homepage: _text(channel, 'link'),
    description: _about(channel),
    casts: casts,
  );
}

/// The longest show notes kept for an episode's Info, in characters: the
/// whole of any real episode's, while a runaway feed cannot fill memory.

const castNotesLength = 20000;

/// The full show notes of the episode [guid] in the feed [xml], as plain
/// text with its paragraphs, or null when the feed no longer lists it.
///
/// 20261025 gjw The fullest text the item has, `content:encoded` first,
/// where [parseFeed] keeps a short summary for the list. Matched on the
/// guid, or the audio URL that stands in for a missing one, as [parseFeed]
/// does.

String? castNotes(String xml, String guid) {
  final channel = XmlDocument.parse(xml).findAllElements('channel').firstOrNull;
  for (final item in channel?.findElements('item') ?? <XmlElement>[]) {
    final url = item.getElement('enclosure')?.getAttribute('url')?.trim();
    if ((_text(item, 'guid') ?? url) != guid) continue;

    final notes = plainText(
      _text(item, 'content:encoded') ??
          _text(item, 'description') ??
          _text(item, 'itunes:summary') ??
          '',
      limit: castNotesLength,
      paragraphs: true,
    );

    return notes.isEmpty ? null : notes;
  }

  return null;
}

/// The channel's own description, as plain text, or null when it has none.

String? _about(XmlElement channel) {
  final text = plainText(
    _text(channel, 'itunes:summary') ??
        _text(channel, 'description') ??
        _text(channel, 'itunes:subtitle') ??
        '',
    limit: podcastDescriptionLength,
  );

  return text.isEmpty ? null : text;
}

Cast? _cast(XmlElement item) {
  final enclosure = item.getElement('enclosure');
  final url = enclosure?.getAttribute('url')?.trim();
  if (url == null || url.isEmpty || !_isAudio(enclosure!, url)) return null;

  return Cast(
    guid: _text(item, 'guid') ?? url,
    title: _text(item, 'title') ?? _text(item, 'itunes:title') ?? 'Untitled',
    published:
        parseRfc822(_text(item, 'pubDate') ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    audioUrl: url,
    duration: parseItunesDuration(_text(item, 'itunes:duration') ?? ''),
    description: plainText(
      _text(item, 'itunes:summary') ??
          _text(item, 'description') ??
          _text(item, 'content:encoded') ??
          '',
      limit: castDescriptionLength,
    ),
  );
}

/// An enclosure is audio when its type says so, or when it states no type
/// and the URL looks like audio. Video podcasts are left out: RadioPod plays
/// sound only.

bool _isAudio(XmlElement enclosure, String url) {
  final type = enclosure.getAttribute('type')?.toLowerCase() ?? '';
  if (type.isNotEmpty) return type.startsWith('audio/');

  return RegExp(
    r'\.(mp3|m4a|aac|ogg|oga|opus|wav)(\?|$)',
    caseSensitive: false,
  ).hasMatch(url);
}

String? _text(XmlElement parent, String name) {
  final s = parent.getElement(name)?.innerText.trim();

  return s == null || s.isEmpty ? null : s;
}

String? _attr(XmlElement parent, String name, String attr) {
  final s = parent.getElement(name)?.getAttribute(attr)?.trim();

  return s == null || s.isEmpty ? null : s;
}

/// `itunes:duration` as seconds, `mm:ss` or `hh:mm:ss`, or null.

Duration? parseItunesDuration(String s) {
  final parts = s.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return null;

  var seconds = 0;
  for (final p in parts) {
    final n = num.tryParse(p.trim());
    if (n == null || n < 0) return null;
    seconds = seconds * 60 + n.floor();
  }

  return seconds == 0 ? null : Duration(seconds: seconds);
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

const _zones = {
  'ut': 0, 'utc': 0, 'gmt': 0, 'z': 0, //
  'est': -5, 'edt': -4, 'cst': -6, 'cdt': -5,
  'mst': -7, 'mdt': -6, 'pst': -8, 'pdt': -7,
};

/// An RSS date such as `Wed, 15 Oct 2026 19:00:00 +0000`, as UTC, or null.
///
/// The day name is optional, seconds are optional, the zone may be numeric
/// or one of the old names, and a two-digit year is read as 20xx. An ISO 8601
/// date, which some feeds use in breach of RSS, is accepted too.

DateTime? parseRfc822(String s) {
  final m = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\s+(\d{2,4})\s+'
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]+)?',
  ).firstMatch(s);
  if (m == null) return DateTime.tryParse(s.trim())?.toUtc();

  final month = _months[m[2]!.toLowerCase()];
  if (month == null) return null;
  var year = int.parse(m[3]!);
  if (year < 100) year += 2000;

  final utc = DateTime.utc(
    year,
    month,
    int.parse(m[1]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
    int.parse(m[6] ?? '0'),
  );

  final zone = m[7];
  if (zone == null) return utc;
  if (zone.startsWith('+') || zone.startsWith('-')) {
    final sign = zone.startsWith('-') ? -1 : 1;
    final minutes =
        int.parse(zone.substring(1, 3)) * 60 + int.parse(zone.substring(3, 5));

    return utc.subtract(Duration(minutes: sign * minutes));
  }
  final hours = _zones[zone.toLowerCase()] ?? 0;

  return utc.subtract(Duration(hours: hours));
}

/// Show notes as plain text: tags removed, common entities decoded, white
/// space squashed, cut to [limit] characters at a word with an ellipsis.

String plainText(String html, {required int limit, bool paragraphs = false}) {
  var s = html
      .replaceAll(
        RegExp(r'</(p|div)\s*>', caseSensitive: false),
        paragraphs ? '\n\n' : ' ',
      )
      .replaceAll(
        RegExp(r'<(br|/li)\s*/?>', caseSensitive: false),
        paragraphs ? '\n' : ' ',
      )
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m[1]!)),
      )
      .replaceAll('&amp;', '&');
  s = paragraphs
      ? s
            .replaceAll(RegExp(r'[ \t\r\f]+'), ' ')
            .replaceAll(RegExp(r' ?\n ?'), '\n')
            .replaceAll(RegExp(r'\n{2,}'), '\n\n')
            .trim()
      : s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length <= limit) return s;

  s = s.substring(0, limit);
  final cut = s.lastIndexOf(' ');

  return '${(cut > limit ~/ 2 ? s.substring(0, cut) : s).trimRight()}…';
}
