/// Station icons — fetch, scale and store a station's artwork.
///
// Time-stamp: <Wednesday 2026-09-23 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

/// Width a stored icon is scaled to, in pixels.
///
/// Rows draw the icon at 40 logical pixels, so 96 covers a 2x display with a
/// little to spare. It is deliberately not larger: a station's icon travels
/// to the Pod inside the station list, and that whole list is rewritten on
/// every edit, so each icon is a cost paid over and over. Height follows the
/// source's aspect ratio rather than being forced square, because a fair few
/// station logos are wide.

const stationIconWidth = 96;

/// Largest source image accepted, before scaling.
///
/// Station artwork URLs are arbitrary and point at whatever the broadcaster
/// uploaded, sometimes a multi-megabyte press photo. Reading that into
/// memory to produce a 96 pixel icon is not worth it.

const _maxSourceBytes = 4 * 1024 * 1024;

/// Download the artwork at [url] and return it ready to store.
///
/// Returns null when there is nothing usable there — which is the common
/// case, not an error. Radio-Browser's favicon field is frequently a dead
/// link, an HTML error page, or a format Flutter cannot decode, so the
/// caller reports "no icon found" rather than treating it as a failure.

Future<String?> fetchStationIcon(String url) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }

    final res = await http
        .get(uri, headers: {'User-Agent': 'RadioPod'})
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) return null;
    if (res.bodyBytes.length > _maxSourceBytes) return null;

    return await encodeStationIcon(res.bodyBytes);
  } catch (e) {
    debugPrint('[StationIcon] could not fetch $url: $e');

    return null;
  }
}

/// Scale [bytes] to [stationIconWidth] and return base64 PNG, or null when
/// the bytes are not an image Flutter can decode.
///
/// Re-encoding rather than storing the original is the point: it bounds the
/// size, and it turns whatever the source was — ICO, JPEG, WebP — into one
/// format every platform can draw.

Future<String?> encodeStationIcon(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: stationIconWidth,
    );
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();

    if (png == null) return null;

    return base64Encode(png.buffer.asUint8List());
  } catch (e) {
    debugPrint('[StationIcon] not a usable image: $e');

    return null;
  }
}

/// Decode a stored icon for display, or null when there is none.
///
/// Tolerates rubbish rather than throwing: the value comes from the Pod and
/// may have been written by an older version or edited by hand, and a
/// station with an unreadable icon should still appear in the list.

Uint8List? decodeStationIcon(String? icon) {
  if (icon == null || icon.isEmpty) return null;
  try {
    return base64Decode(icon);
  } catch (e) {
    debugPrint('[StationIcon] discarding unreadable icon: $e');

    return null;
  }
}
