/// CastStore — every podcast's casts, and where the listener is in them.
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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/models/cast.dart';
import 'package:radiopod/utils/cast_merge.dart';

/// The casts of every podcast in the library, keyed by the podcast's
/// station id, held in memory and on the device.
///
/// 20261016 gjw Static, like Player, because the audio handler has to
/// record progress with no AppProvider alive: Android Auto and CarPlay start
/// the media service on their own, before any screen or login. So the
/// handler writes here and this writes the device; AppProvider reads it,
/// merges it with the Pod's copy by `updatedAt` (see `mergeCastMaps`), and
/// writes the Pod when one is in use.
///
/// PRIVACY. The device copy is plain JSON, like the station mirror in
/// LocalStore, and holds a little more: which episodes have been heard and
/// how far into each. It never leaves the device except to the user's own
/// Pod.

class CastStore {
  CastStore._();

  static const _key = 'cached_casts';

  static Map<String, List<Cast>> _casts = {};
  static final _changes = StreamController<String>.broadcast();

  /// The id of each podcast whose casts change, as they change.

  static Stream<String> get changes => _changes.stream;

  /// Every podcast's casts. Read-only; change them through the methods.

  static Map<String, List<Cast>> get all => Map.unmodifiable(_casts);

  /// One podcast's casts, newest first, or none.

  static List<Cast> of(String podcastId) => _casts[podcastId] ?? const [];

  /// Read the device copy into memory.

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _casts = decodeCasts(prefs.getString(_key));
    } catch (e) {
      debugPrint('[CastStore] load error: $e');
      _casts = {};
    }
  }

  /// Replace everything, as after reconciling with the Pod, and save.
  ///
  /// 20261017 gjw Announces NO change. Its one caller, the Pod load, works
  /// out for itself whether the Pod needs writing and then updates the
  /// screen and the player. Announcing it marked every load as unsaved
  /// progress, so each read of the Pod was followed by writing it back.

  static Future<void> replaceAll(Map<String, List<Cast>> casts) async {
    _casts = {for (final e in casts.entries) e.key: List.of(e.value)};
    await _save();
  }

  /// Set one podcast's casts, as after a feed refresh, and save.

  static Future<void> put(String podcastId, List<Cast> casts) async {
    _casts[podcastId] = List.of(casts);
    _changes.add(podcastId);
    await _save();
  }

  /// Change one cast and save. Does nothing if it is not there.

  static Future<void> update(
    String podcastId,
    String guid,
    Cast Function(Cast) change,
  ) async {
    final casts = _casts[podcastId];
    final i = casts?.indexWhere((c) => c.guid == guid) ?? -1;
    if (i < 0) return;

    casts![i] = change(casts[i]);
    _changes.add(podcastId);
    await _save();
  }

  /// Drop the casts of podcasts no longer in the library.

  static Future<void> retainOnly(Set<String> podcastIds) async {
    final before = _casts.length;
    _casts.removeWhere((id, _) => !podcastIds.contains(id));
    if (_casts.length != before) await _save();
  }

  /// Forget everything, with the rest of the device copy. For when the
  /// device IS the library: logged out.

  static Future<void> clear() async {
    _casts = {};
    await clearDevice();
  }

  /// Forget only the device copy, keeping the casts in memory.
  ///
  /// For when a Pod holds the library. Emptying memory there would let the
  /// next save write an empty cast list over the Pod's.

  static Future<void> clearDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, encodeCasts(_casts));
    } catch (e) {
      debugPrint('[CastStore] save error: $e');
    }
  }

  /// Forget the in-memory copy without touching the device. Tests only.

  @visibleForTesting
  static void resetForTest() => _casts = {};
}

/// The cast map as JSON text, for the device and for `casts.ttl`.

String encodeCasts(Map<String, List<Cast>> casts) => jsonEncode({
  for (final e in casts.entries)
    e.key: [for (final c in e.value.take(maxCastsPerPodcast)) c.toJson()],
});

/// The cast map from JSON text. Anything unreadable is dropped, podcast by
/// podcast, rather than costing every podcast its casts.

Map<String, List<Cast>> decodeCasts(String? json) {
  if (json == null || json.isEmpty) return {};

  final Object? raw;
  try {
    raw = jsonDecode(json);
  } catch (e) {
    debugPrint('[CastStore] discarding unreadable casts: $e');

    return {};
  }
  if (raw is! Map<String, dynamic>) return {};

  final result = <String, List<Cast>>{};
  for (final e in raw.entries) {
    try {
      result[e.key] = [
        for (final c in (e.value as List).cast<Map<String, dynamic>>())
          Cast.fromJson(c),
      ];
    } catch (err) {
      debugPrint('[CastStore] discarding casts of ${e.key}: $err');
    }
  }

  return result;
}
