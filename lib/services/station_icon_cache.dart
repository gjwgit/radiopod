/// StationIconCache — user-chosen station icons, as files the car can show.
///
// Time-stamp: <Monday 2026-10-05 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0
//
/// Authors: Graham Williams

library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/platform_io.dart'
    if (dart.library.js_interop) 'package:radiopod/utils/platform_web.dart';
import 'package:radiopod/utils/station_icon.dart';

/// 20261005 gjw Writes [Station.icon] out as a file so Android Auto and
/// CarPlay can display it.
///
/// WHY A FILE. A station's own logo is a URL and goes straight into
/// `MediaItem.artUri`. A picture the user chose is not a URL: it is base64
/// held in [Station.icon], carried in the Pod data, and there is nothing for
/// a head unit to fetch. So the browse tree showed the station logo and
/// nothing at all for the icons someone had gone out of their way to pick.
///
/// A `file://` artUri works, despite what browse_tree.dart used to assume.
/// audio_service resolves it ON THE DART SIDE into an `artCacheFile` extra
/// (audio_service.dart:1058) and the native service loads the bitmap IN THIS
/// PROCESS, putting it into the metadata as ALBUM_ART and DISPLAY_ICON
/// (AudioService.java:811). The image therefore travels with the metadata
/// and the car never reads our files — which is just as well, since these
/// live in app-private storage that Google's process cannot open.
///
/// SYNCHRONOUS LOOKUP IS THE POINT. `stationMediaItem` is a pure function
/// called from four places in the audio handler and the CarPlay bridge;
/// making it async would spread through all of them. So the writing happens
/// once, when the library is pushed to the player, and the lookup afterwards
/// is a map read.

class StationIconCache {
  StationIconCache._();

  /// stationId -> absolute path of the written icon.

  static final Map<String, String> _paths = {};

  /// stationId -> hashCode of the icon last written, so an unchanged library
  /// rewrites nothing. The whole station list is pushed on EVERY mutation
  /// (CLAUDE.md §5), so without this a rename would rewrite every icon.
  ///
  /// hashCode, not a cryptographic digest: this only has to notice that the
  /// user picked a different picture, it never leaves memory, and it saves a
  /// dependency. It is not stable across runs, which costs one needless
  /// rewrite per station per launch and nothing else.

  static final Map<String, int> _digests = {};

  static Directory? _dir;

  /// The file written for [stationId], or null when that station has no
  /// user-chosen icon. Safe to call from synchronous code.

  static String? pathFor(String stationId) => _paths[stationId];

  /// The URI to publish for [stationId]'s icon, or null when it has none.
  ///
  /// 20261006 gjw ANDROID GETS A content:// URI, and it matters which
  /// surface is asking. The wide now-playing view draws the bitmap
  /// audio_service loads in our own process, so a file:// URI has always
  /// worked there. The browse list and the NARROW now-playing card beside
  /// the map are rendered by Android Auto from the URI itself, and Auto
  /// cannot read our app-private files — so those two showed a station's
  /// own https logo and nothing at all for a picture the user chose.
  ///
  /// [StationIconProvider] serves this directory to the Auto host, so the
  /// URI below is one Auto can actually open. Everywhere else the file URI
  /// stands: the OS media layer reads it in our process and it displays.

  static Uri? uriFor(String stationId) {
    final path = _paths[stationId];
    if (path == null) return null;
    if (!usesContentIcons) return Uri.file(path);

    // Matches android:authorities in AndroidManifest.xml and the
    // <files-path name> in res/xml/station_icon_paths.xml. Station ids are
    // uuids, so nothing here needs escaping, but pathSegments encodes
    // anyway rather than relying on that.

    return Uri(
      scheme: 'content',
      host: '$androidApplicationId.stationicons',
      pathSegments: ['station_icons', _fileName(stationId)],
    );
  }

  static String _fileName(String stationId) => '$stationId.png';

  /// Write out the icons for [stations], and forget any that have gone.
  ///
  /// Best-effort throughout: a cache that cannot be written costs an icon in
  /// the car, which must never be allowed to break the library push that
  /// carries it.

  static Future<void> sync(List<Station> stations) async {
    try {
      final dir = await _iconDir();
      if (dir == null) return;

      final live = <String>{};

      for (final station in stations) {
        final icon = station.icon;
        if (icon == null || icon.isEmpty) {
          _forget(station.id);
          continue;
        }

        live.add(station.id);

        // Hash the ENCODED string rather than the decoded bytes: it is what
        // changes when the user picks a new picture, and hashing it avoids
        // decoding an icon that is already on disk.

        final digest = icon.hashCode;
        if (_digests[station.id] == digest && _paths[station.id] != null) {
          continue;
        }

        final bytes = decodeStationIcon(icon);
        if (bytes == null) {
          _forget(station.id);
          continue;
        }

        final file = File('${dir.path}/${station.id}.png');
        await file.writeAsBytes(bytes, flush: true);

        _paths[station.id] = file.path;
        _digests[station.id] = digest;
      }

      // Stations deleted while the app was running.

      for (final id in _paths.keys.toList()) {
        if (!live.contains(id)) _forget(id);
      }
    } on Object catch (e) {
      debugPrint('[StationIconCache] sync failed: $e');
    }
  }

  static void _forget(String stationId) {
    final path = _paths.remove(stationId);
    _digests.remove(stationId);
    if (path != null) {
      File(path).delete().catchError((_) => File(path));
    }
  }

  static Future<Directory?> _iconDir() async {
    if (_dir != null) return _dir;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/station_icons');
      if (!dir.existsSync()) await dir.create(recursive: true);

      return _dir = dir;
    } on Object catch (e) {
      debugPrint('[StationIconCache] no cache directory: $e');

      return null;
    }
  }

  /// Records a path without touching the filesystem. For tests, so the
  /// browse tree's preference for a chosen icon can be exercised without
  /// writing files.

  @visibleForTesting
  static void debugSetPath(String stationId, String path) {
    _paths[stationId] = path;
  }

  /// Clears the in-memory maps. For tests.

  @visibleForTesting
  static void resetForTest() {
    _paths.clear();
    _digests.clear();
    _dir = null;
  }
}
