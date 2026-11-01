/// GeoBlock — tell a station refusing our country from one that failed.
///
// Time-stamp: <Wednesday 2026-10-14 09:00:00 +1100 Graham Williams>
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

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

/// A station whose server will not stream to the listener's country, and
/// that country as the server named it ('' when it did not say).

typedef GeoBlock = ({String station, String country});

/// The country a stream's response [headers] say is refused, or null when
/// the stream is not refusing us.
///
/// 20261014 gjw United Radio (Virgin Radio Italy and its Music Star
/// stations) answers a listener outside Italy with an ordinary 200, then
/// sends a few seconds' burst of audio and stalls. Nothing in the audio
/// says why; only the headers do, as `X-allowed-country: no` beside
/// `X-country: AU`. The player cannot see headers, so to the listener it
/// looked like a station that kept dropping out and then skipped. The
/// header names are that server's own, not any standard. The keys arrive
/// lower-cased from package:http.

String? blockedCountry(Map<String, String> headers) {
  if (headers['x-allowed-country']?.trim().toLowerCase() != 'no') return null;

  return headers['x-country']?.trim() ?? '';
}

/// Open [url] just far enough to read its headers, and report whether the
/// server refuses our country. Null on any failure: a probe that cannot
/// connect proves nothing, and the player is already moving on.

Future<String?> probeGeoBlock(String url) async {
  final client = http.Client();
  try {
    final response = await client
        .send(http.Request('GET', Uri.parse(url)))
        .timeout(const Duration(seconds: 10));

    return blockedCountry(response.headers);
  } catch (e) {
    debugPrint('[GeoBlock] could not read headers for $url: $e');

    return null;
  } finally {
    // Hang up before the audio itself starts arriving.

    client.close();
  }
}
