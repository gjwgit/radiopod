/// PodService — save and load encrypted RadioPod data on a Solid Pod.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:flutter/foundation.dart';

import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

/// Reads and writes RadioPod's data files on the user's Solid Pod.
///
/// Each file is a JSON array embedded as a literal in a Turtle (.ttl) file,
/// which solidpod encrypts — `writePod` encrypts by default, so both the
/// station library and the playlists are ciphertext at rest. Nobody with
/// access to the server, including its administrators, can read which
/// stations the user listens to.
///
/// The service is deliberately generic over the payload: it moves JSON text,
/// and AppProvider owns the Station and Playlist types.

class PodService {
  PodService._();

  static const _prefixes =
      '@prefix radiopod: <https://'
      'radiopod.solidcommunity.au/ont/> .\n'
      '@prefix xsd:      <http://'
      'www.w3.org/2001/XMLSchema#> .\n';

  // ── Turtle helpers ────────────────────────────────────────────────────────

  static String _buildTtl(String fileName, String json) =>
      '$_prefixes\n'
      'radiopod:${fileName.replaceAll('.', '_')} a radiopod:DataFile ;\n'
      '  radiopod:data """$json""" .\n';

  static String? _extractJson(String ttl) {
    final match = RegExp(
      r'radiopod:data\s+"""(.*?)"""',
      dotAll: true,
    ).firstMatch(ttl);

    return match?.group(1)?.trim();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Save [json] to [fileName] on the Pod.
  ///
  /// Returns an error message on failure, or null on success. The write is
  /// registered with [SolidPendingWrites] so a failure that nothing awaits
  /// still reaches the user through solidui's write-failure listener.

  static Future<String?> save(String fileName, String json) async {
    try {
      final ttl = _buildTtl(fileName, json);
      await SolidPendingWrites.track(writePod(fileName, ttl, overwrite: true));

      return null;
    } catch (e) {
      debugPrint('[PodService] save error ($fileName): $e');

      return e.toString();
    }
  }

  /// Load the JSON stored in [fileName] on the Pod.
  ///
  /// Returns null when the file does not exist yet or cannot be read, which
  /// the caller treats as "nothing saved" rather than as an error — a new
  /// user has no data files until the first save. An empty JSON array comes
  /// back as an empty string's caller-visible equivalent: an empty list.

  static Future<String?> load(String fileName) async {
    try {
      final ttl = await readPod(fileName);
      if (ttl.isEmpty) return null;

      return _extractJson(ttl);
    } catch (e) {
      debugPrint('[PodService] load error ($fileName): $e');

      return null;
    }
  }
}
