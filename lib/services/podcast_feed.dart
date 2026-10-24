/// PodcastFeed — fetch a podcast's RSS feed from its publisher.
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

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/utils/rss.dart';

/// Fetch and parse the feed at [url].
///
/// PRIVACY. This goes to the podcast's own publisher, as a stream goes to
/// the broadcaster: it is where the podcast lives, and the request says no
/// more than that RadioPod wants the feed. Nothing about the listener's
/// progress is sent.
///
/// Throws on a network failure, a non-200 answer or a body that is not a
/// feed, so the caller can say which.

Future<PodcastFeed> fetchFeed(String url) async {
  final uri = Uri.parse(url);
  final res = await http
      .get(uri, headers: {'User-Agent': userAgent})
      .timeout(const Duration(seconds: 20));

  if (res.statusCode != 200) {
    throw http.ClientException(
      'The podcast server answered ${res.statusCode}.',
      uri,
    );
  }

  // 20261016 gjw Parsed off the UI thread. The Daily's feed is 20 MB and
  // three thousand episodes, and took most of a second to parse on the
  // desktop; on a phone that would freeze the list mid-scroll. On the web
  // compute runs in place, which is no worse than before.

  return compute(parseFeed, utf8.decode(res.bodyBytes, allowMalformed: true));
}

/// The full show notes already fetched this session, by feed and guid.

final _notes = <String, String?>{};

/// The full show notes of episode [guid] of the feed at [url]; see
/// [castNotes]. Fetched once a session: the list keeps only a summary,
/// and the whole text is wanted only when the listener asks.
///
/// Throws as [fetchFeed] does.

Future<String?> fetchCastNotes(String url, String guid) async {
  final key = '$url\n$guid';
  if (_notes.containsKey(key)) return _notes[key];

  final uri = Uri.parse(url);
  final res = await http
      .get(uri, headers: {'User-Agent': userAgent})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw http.ClientException(
      'The podcast server answered ${res.statusCode}.',
      uri,
    );
  }

  final xml = utf8.decode(res.bodyBytes, allowMalformed: true);

  return _notes[key] = await compute(_notesOf, (xml: xml, guid: guid));
}

String? _notesOf(({String xml, String guid}) a) => castNotes(a.xml, a.guid);
