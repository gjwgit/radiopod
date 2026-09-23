/// RadioBrowser — search the community-run Radio-Browser station database.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:radiopod/models/station.dart';

const _uuid = Uuid();

/// How a search query is matched against the Radio-Browser database.

enum SearchField {
  name('name', 'Name'),
  tag('tag', 'Genre');

  const SearchField(this.parameter, this.label);

  /// The `/json/stations/search` query parameter this field maps to.

  final String parameter;

  /// The label shown on the segmented control in the Search screen.

  final String label;
}

/// Read-only client for the Radio-Browser API.
///
/// PRIVACY. This is the one service in RadioPod that talks to a third party,
/// and it is only reached when the user actively searches. Exactly two things
/// leave the device: the search text and the User-Agent naming the app, which
/// the Radio-Browser terms of use require. No WebID, no Pod address, no
/// station library, and no listening history is ever sent. The `/json/url/`
/// click-reporting endpoint, which tells Radio-Browser what is being played,
/// is deliberately NOT called — RadioPod contributes no telemetry.

class RadioBrowser {
  RadioBrowser._();

  /// Identifies the app to Radio-Browser, as their terms of use require.

  static const _userAgent =
      'RadioPod/1.0.14 (+https://github.com/gjwgit/radiopod)';

  /// Endpoint listing the currently available API mirrors.

  static const _discoveryUrl =
      'https://all.api.radio-browser.info/json/servers';

  /// Mirror used when discovery fails, e.g. on a restricted network.

  static const _fallbackHost = 'de1.api.radio-browser.info';

  /// Mirror chosen for this session.
  ///
  /// Radio-Browser asks clients to spread load across mirrors rather than
  /// pinning one, so a host is picked once per run and reused. Resolving it
  /// per search would multiply the requests for no benefit.

  static String? _host;

  static Future<String> _resolveHost() async {
    if (_host != null) return _host!;

    try {
      final res = await http
          .get(Uri.parse(_discoveryUrl), headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final servers = (jsonDecode(res.body) as List)
            .cast<Map<String, dynamic>>()
            .map((s) => s['name'] as String?)
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList();
        if (servers.isNotEmpty) {
          servers.shuffle();
          _host = servers.first;

          return _host!;
        }
      }
    } catch (e) {
      debugPrint('[RadioBrowser] server discovery failed: $e');
    }

    _host = _fallbackHost;

    return _host!;
  }

  /// Search for stations matching [query] on [field].
  ///
  /// Broken stations are filtered out server-side and results come back most
  /// listened-to first, which is the ordering that makes a short list useful.
  /// Throws on a network or server failure so the caller can report it.

  static Future<List<Station>> search(
    String query, {
    SearchField field = SearchField.name,
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final host = await _resolveHost();
    final uri = Uri.https(host, '/json/stations/search', {
      field.parameter: trimmed,
      'limit': '$limit',
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
    });

    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw http.ClientException(
        'Radio-Browser returned ${res.statusCode}.',
        uri,
      );
    }

    final stations = (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .cast<Map<String, dynamic>>()
        .map(_toStation)
        .whereType<Station>()
        .toList();

    // 20260922 gjw Put continuous streams above HLS ones, keeping
    // Radio-Browser's popularity order within each group. Broadcasters often
    // publish a station both ways and the HLS entry can easily be the more
    // popular — ABC News Radio's is — yet it is the one that dies after a
    // minute on the desktop. Offering the workable entry first saves the
    // user diagnosing a station that was never going to play properly.

    return uniqueByUrl([
      for (final s in stations)
        if (!s.isHls) s,
      for (final s in stations)
        if (s.isHls) s,
    ]);
  }

  /// Convert one Radio-Browser record to a [Station], or null if unusable.
  ///
  /// `url_resolved` is preferred over `url`: Radio-Browser follows playlist
  /// redirects for us and stores the actual stream there, so using it avoids
  /// handing just_audio an .m3u/.pls file where it expects audio. A record
  /// with neither a name nor a URL is dropped rather than saved as a station
  /// that can never play.

  static Station? _toStation(Map<String, dynamic> j) {
    final url = _str(j['url_resolved']) ?? _str(j['url']);
    final name = _str(j['name']);
    if (url == null || name == null) return null;

    return Station(
      id: _uuid.v4(),
      name: name,
      url: url,
      homepage: _str(j['homepage']),
      favicon: _str(j['favicon']),
      country: _str(j['country']),
      language: _str(j['language']),
      codec: _str(j['codec']),
      bitrate: (j['bitrate'] as num?)?.toInt(),
      tags: _str(j['tags'])?.split(',').map((t) => t.trim()).toList() ?? [],
      stationUuid: _str(j['stationuuid']),

      // Radio-Browser reports 1 for a playlist-of-segments stream. See
      // Station.isHls for why that matters on the desktop.
      isHls: (j['hls'] as num?)?.toInt() == 1 || _looksLikeHls(url),
    );
  }

  /// A fallback for records whose `hls` flag is not set but whose URL gives
  /// it away, which happens with hand-entered Radio-Browser entries.

  static bool _looksLikeHls(String url) =>
      Uri.tryParse(url)?.path.toLowerCase().endsWith('.m3u8') ?? false;

  /// Trim a JSON string field, mapping empty and non-string values to null.

  static String? _str(Object? v) {
    if (v is! String) return null;
    final s = v.trim();

    return s.isEmpty ? null : s;
  }
}

/// Collapse records that point at the same stream.
///
/// Radio-Browser holds a separate record per submission, so one station can
/// appear many times over — a search for ABC News Radio returns four entries,
/// with different names and logos, that all resolve to the same Icecast
/// address. Listing them all was actively misleading: saving one made the
/// other three show as saved too, because the library matches on stream URL
/// and they ARE the same station. One row per stream is the honest display.
///
/// The key is the exact URL, deliberately the same key the library uses to
/// decide what is already saved. If those two ever diverged the duplicate
/// ticks would come straight back.
///
/// The first record of each stream wins, which after the ordering in
/// [RadioBrowser.search] is the most listened-to continuous one — the entry
/// with the best chance of carrying sensible metadata.

List<Station> uniqueByUrl(List<Station> stations) {
  final seen = <String>{};

  return [
    for (final s in stations)
      if (seen.add(s.url)) s,
  ];
}
