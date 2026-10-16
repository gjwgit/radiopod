/// PodcastIndex — search the open Podcast Index directory.
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

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/scramble.dart';

const _uuid = Uuid();

/// Read-only client for the Podcast Index API, used by Search.
///
/// PRIVACY. The second third party RadioPod talks to, and only when the
/// listener searches for a podcast. What leaves the device is the search
/// text, the app's name, and the API key that identifies RadioPod (not the
/// listener) to Podcast Index. No WebID, no library and no listening is
/// sent. Once a podcast is saved its feed is read from the publisher
/// directly, never through Podcast Index.
///
/// 20261016 gjw The key and secret are supplied at build time, SCRAMBLED,
/// as `PODCAST_INDEX_KEY_X` and `PODCAST_INDEX_SECRET_X` (see
/// `lib/utils/scramble.dart`), so neither appears in the binary as itself.
/// `dart run support/scramble_defines.dart` writes them into the gitignored
/// dart_defines.json from the plain values; CI does the same from its
/// secrets. They are never committed. A build without them still runs; Podcast search
/// says it is not available in that build. A key shipped inside an app can
/// be extracted, which Podcast Index accepts for client apps: it is a rate
/// limit and a contact, not a password.

class PodcastIndex {
  PodcastIndex._();

  static final _key = unscramble(
    const String.fromEnvironment('PODCAST_INDEX_KEY_X'),
  );
  static final _secret = unscramble(
    const String.fromEnvironment('PODCAST_INDEX_SECRET_X'),
  );
  static const _host = 'api.podcastindex.org';

  /// False in a build made without the key and secret.

  static bool get configured => _key.isNotEmpty && _secret.isNotEmpty;

  /// Search podcasts by title, author or topic.
  ///
  /// Returns podcasts as [Station]s, ready to save, most relevant first, one
  /// per feed URL. Throws on a network or server failure, and
  /// [StateError] in a build without a key or with one Podcast Index
  /// refuses.

  static Future<List<Station>> search(String term, {int limit = 50}) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return [];
    if (!configured) {
      throw StateError('Podcast search is not available in this build.');
    }

    final uri = Uri.https(_host, '/api/1.0/search/byterm', {
      'q': trimmed,
      'max': '$limit',
    });
    final res = await http
        .get(uri, headers: podcastIndexHeaders(_key, _secret, DateTime.now()))
        .timeout(const Duration(seconds: 20));

    // 20261016 gjw A refused key is not a network problem, and saying
    // "check your connection" sent the listener looking in the wrong
    // place. It is this build's key or secret, which only a rebuild with
    // the right pair can fix, so it is reported as unavailable instead.

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw StateError(
        'Podcast Index did not accept the key this build of RadioPod '
        'was made with (it answered ${res.statusCode}).',
      );
    }
    if (res.statusCode != 200) {
      throw http.ClientException(
        'Podcast Index returned ${res.statusCode}.',
        uri,
      );
    }

    return podcastsFromSearch(utf8.decode(res.bodyBytes));
  }
}

/// The headers Podcast Index requires: the key, the time, and an SHA-1 of
/// key, secret and time, which proves the secret without sending it.

Map<String, String> podcastIndexHeaders(
  String key,
  String secret,
  DateTime now,
) {
  final date = '${now.toUtc().millisecondsSinceEpoch ~/ 1000}';

  return {
    'User-Agent': userAgent,
    'X-Auth-Key': key,
    'X-Auth-Date': date,
    'Authorization': sha1.convert(utf8.encode('$key$secret$date')).toString(),
  };
}

/// Podcasts from a `search/byterm` answer.
///
/// A feed Podcast Index has marked dead is left out: saving it would give
/// a row that can never play. Feeds are collapsed by URL, as stations are,
/// so a podcast listed twice is offered once.

List<Station> podcastsFromSearch(String body) {
  final json = jsonDecode(body);
  final feeds = json is Map<String, dynamic> ? json['feeds'] : null;
  if (feeds is! List) return [];

  final seen = <String>{};
  final podcasts = <Station>[];
  for (final f in feeds.whereType<Map<String, dynamic>>()) {
    final url = _str(f['url']);
    final title = _str(f['title']);
    if (url == null || title == null || f['dead'] == 1) continue;
    if (!seen.add(url)) continue;

    final categories = f['categories'];
    podcasts.add(
      Station(
        id: _uuid.v4(),
        name: title,
        url: url,
        homepage: _str(f['link']),
        favicon: _str(f['artwork']) ?? _str(f['image']),
        language: _str(f['language']),
        author: _str(f['author']) ?? _str(f['ownerName']),
        tags: categories is Map
            ? categories.values.whereType<String>().toList()
            : const [],
        isPodcast: true,
      ),
    );
  }

  return podcasts;
}

String? _str(Object? v) {
  if (v is! String) return null;
  final s = v.trim();

  return s.isEmpty ? null : s;
}
