/// StationLogoCache — each station's own logo, fetched once and kept.
///
// Time-stamp: <Sunday 2026-10-18 06:00:00 +1100 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0
//
/// Authors: Graham Williams

library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/station_icon_cache.dart';
import 'package:radiopod/utils/station_icon.dart';

/// 20261018 gjw PRIVACY. A logo is a URL on the broadcaster's or the
/// podcaster's own server, and every fetch of it tells that server this
/// address has the station. The list used `Image.network` on every launch,
/// and a playing station handed the URL to the media session, where
/// audio_service downloaded it and Android Auto's OWN process fetched it
/// again, so the logo hosts and the car learnt what was being LISTENED to,
/// as it happened.
///
/// So a library station's logo is fetched ONCE, by RadioPod, and kept as a
/// 96 pixel PNG beside the chosen icons in `station_icons/`, where
/// [StationIconCache.publishedUri] serves it to the car exactly as it serves
/// those. Playing a station never touches the logo's host, and the session
/// is never given a third-party address.
///
/// Kept on the DEVICE, not in the Pod. Logos are not the user's data, a
/// fetch per device per logo reveals the library at most once, and putting
/// them in `stations.ttl` would rewrite every logo on every edit.
///
/// Named by a hash of the URL, so a logo that moves (Update details) is
/// fetched afresh and the old file is dropped with the next [sync].
///
/// Search results are NOT cached: browsing is not listening, and keeping
/// every result's logo would fill the disk with stations never saved.

class StationLogoCache {
  StationLogoCache._();

  /// Bumped whenever a logo arrives, so the rows waiting on one redraw.

  static final changes = ValueNotifier<int>(0);

  /// File names of the logos on disk.

  static final Set<String> _present = {};

  /// URLs asked for this session, and those that gave nothing usable. A
  /// dead logo is tried once per run, not on every rebuild of its row.

  static final Set<String> _asked = {};
  static final Set<String> _failed = {};

  /// One fetch at a time: a library of fifty stations should not open fifty
  /// connections at launch.

  static Future<void> _queue = Future.value();

  static Directory? _dir;
  static Future<bool>? _indexing;

  static String fileName(String url) =>
      'logo_${sha1.convert(utf8.encode(url))}.png';

  /// The kept logo for [url], or null. Synchronous, for build methods and
  /// the pure browse tree.

  static String? pathFor(String? url) {
    final dir = _dir;
    if (url == null || url.isEmpty || dir == null) return null;
    final name = fileName(url);

    return _present.contains(name) ? '${dir.path}/$name' : null;
  }

  /// The URI to publish to the media session for [url], or null.

  static Uri? uriFor(String? url) {
    final path = pathFor(url);

    return path == null ? null : StationIconCache.publishedUri(path);
  }

  /// The kept logo as a stored icon, so Properties → Download needs no
  /// network when the logo is already here.

  static String? iconFor(String? url) {
    final path = pathFor(url);
    if (path == null) return null;
    try {
      return base64Encode(File(path).readAsBytesSync());
    } on Object {
      return null;
    }
  }

  /// Fetch [url] in the background unless it is kept already. Safe to call
  /// from a build method: repeated calls cost a set lookup.

  static void request(String? url) {
    if (kIsWeb || url == null || url.isEmpty) return;
    if (_failed.contains(url) || !_asked.add(url)) return;
    _queue = _queue.then((_) => _fetch(url)).catchError((Object e) {
      debugPrint('[StationLogoCache] $e');
    });
  }

  /// Fetch the logos [stations] lack and drop those no station uses.
  ///
  /// A station with a chosen icon needs no logo: the icon wins everywhere.
  /// An EMPTY library deletes nothing, because the car can start on a
  /// device copy that is not loaded yet, and wiping the cache there would
  /// only fetch every logo again.

  static Future<void> sync(List<Station> stations) async {
    if (kIsWeb || !await _index()) return;

    final wanted = <String>{};
    for (final s in stations) {
      final url = s.favicon;
      final icon = s.icon;
      if (url == null || url.isEmpty || (icon != null && icon.isNotEmpty)) {
        continue;
      }
      wanted.add(fileName(url));
      request(url);
    }
    if (stations.isEmpty) return;

    for (final name in _present.toList()) {
      if (wanted.contains(name)) continue;
      _present.remove(name);
      File('${_dir!.path}/$name').delete().catchError((_) => File(name));
    }
  }

  static Future<void> _fetch(String url) async {
    if (!await _index()) return;
    final name = fileName(url);
    if (_present.contains(name)) return;

    final bytes = _decode(await fetchStationIcon(url));
    if (bytes == null) {
      _failed.add(url);
      return;
    }
    await File('${_dir!.path}/$name').writeAsBytes(bytes, flush: true);
    _present.add(name);
    changes.value++;
  }

  static Uint8List? _decode(String? icon) {
    if (icon == null) return null;
    try {
      return base64Decode(icon);
    } on Object {
      return null;
    }
  }

  /// Find the directory and list what is already kept, once.

  static Future<bool> _index() => _indexing ??= () async {
    final dir = await StationIconCache.directory();
    if (dir == null) return false;
    try {
      for (final entry in dir.listSync()) {
        final name = entry.uri.pathSegments.last;
        if (name.startsWith('logo_')) _present.add(name);
      }
    } on Object catch (e) {
      debugPrint('[StationLogoCache] could not list the cache: $e');
    }
    _dir = dir;
    if (_present.isNotEmpty) changes.value++;

    return true;
  }();

  /// Pretend [url] is kept in [dir]. For tests, without touching files.

  @visibleForTesting
  static void debugSetKept(String url, String dir) {
    _dir = Directory(dir);
    _indexing = Future.value(true);
    _present.add(fileName(url));
  }

  @visibleForTesting
  static void resetForTest() {
    _present.clear();
    _asked.clear();
    _failed.clear();
    _dir = null;
    _indexing = null;
    _queue = Future.value();
  }
}
