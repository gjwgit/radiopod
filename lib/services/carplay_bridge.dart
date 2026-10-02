/// CarPlay bridge — hands the station library to the native CarPlay scene.
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
/// Authors: Tony Chen

library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:audio_service/audio_service.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/browse_tree.dart';

/// The Dart end of the channel to `ios/Runner/CarPlaySceneDelegate.swift`.
///
/// Android Auto reads the browse tree through audio_service, but audio_service
/// has no CarPlay support, so on iOS the car's lists are drawn natively from
/// what this bridge sends. The payload is built from the SAME browse tree, so
/// the car shows the same stations in the same order on both platforms, and
/// a tap in CarPlay comes back as a media id that goes through the same
/// [AudioHandler.playFromMediaId] as a tap in Android Auto.
///
/// Everything here is a no-op off iOS.

class CarPlayBridge {
  CarPlayBridge._();

  static const _channel = MethodChannel('com.togaware.radiopod/carplay');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Listen for taps from the car and report the station on air to it.
  ///
  /// Called once from Player.init, after the handler exists.

  static void attach(AudioHandler handler) {
    if (!_supported) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'playFromMediaId') {
        throw MissingPluginException('Unknown CarPlay call ${call.method}');
      }

      // Awaited so a station that will not open reaches the car as an error
      // the driver can be told about, rather than a silent Now Playing screen.

      try {
        await handler.playFromMediaId(call.arguments as String);
      } catch (e) {
        throw PlatformException(
          code: 'play_failed',
          message: 'The station did not respond. Try another station.',
          details: '$e',
        );
      }
    });

    // Only the station id matters to the car: it marks the row on air. The
    // track title reaches the Now Playing screen through audio_service.

    handler.mediaItem
        .map((m) => m?.extras?['stationId'] as String?)
        .distinct()
        .listen(
          (id) => _send('setNowPlaying', {'stationId': id}),
          onError: (Object e) => debugPrint('[CarPlayBridge] $e'),
        );
  }

  /// Send the library to the car. Called on every library change.

  static void publishLibrary(List<Station> stations, List<Playlist> playlists) {
    if (!_supported) return;
    _send('setLibrary', carPlayLibrary(stations, playlists));
  }

  static void _send(String method, Object? arguments) {
    unawaited(
      _channel.invokeMethod<void>(method, arguments).catchError((Object e) {
        // No CarPlay scene support (e.g. a test host) is not an error worth
        // more than a log line; the phone app is unaffected.

        debugPrint('[CarPlayBridge] $method failed: $e');
      }),
    );
  }
}

/// The library as the plain maps the native side reads.
///
/// Two lists, one per CarPlay tab: every saved station, as the All Stations
/// folder presents them, and every playlist with its stations. Each station
/// carries its browse media id, so Next and Previous in the car move through
/// the list the driver picked it from.

Map<String, Object?> carPlayLibrary(
  List<Station> stations,
  List<Playlist> playlists,
) {
  Map<String, Object?> station(MediaItem m) => {
    'mediaId': m.id,
    'stationId': m.extras?['stationId'],
    'title': m.title,
    'subtitle': m.artist,
    'artUri': m.artUri?.toString(),
  };

  return {
    'stations': [
      for (final m in browseChildren(browseAllStationsId, stations, playlists))
        station(m),
    ],
    'playlists': [
      for (final folder in browseRoot(playlists))
        if (folder.id != browseAllStationsId)
          {
            'id': folder.id,
            'title': folder.title,
            'subtitle': folder.displaySubtitle,
            'stations': [
              for (final m in browseChildren(folder.id, stations, playlists))
                station(m),
            ],
          },
    ],
  };
}
