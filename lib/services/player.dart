/// Player — one-time setup and global access to the audio handler.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
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

import 'package:flutter/foundation.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/services/carplay_bridge.dart';
import 'package:radiopod/services/local_store.dart';
import 'package:radiopod/services/radio_audio_handler.dart';
import 'package:radiopod/services/sleep_preference.dart';
import 'package:radiopod/services/sleep_timer.dart';
import 'package:radiopod/services/station_icon_cache.dart';
import 'package:radiopod/utils/platform_io.dart'
    if (dart.library.js_interop) 'package:radiopod/utils/platform_web.dart';

/// Holds the one [RadioAudioHandler] for the life of the process.
///
/// A singleton because the media session is a singleton: Android allows one
/// MediaBrowserService per app, and the notification, the lock screen and
/// Android Auto all talk to that one instance. `AudioService.init` asserts if
/// it is called twice, so [init] is called exactly once from main().

class Player {
  Player._();

  static RadioAudioHandler? _handler;

  static SleepTimer? _sleepTimer;

  /// The sleep timer, which stops playback at a time the listener chose.
  ///
  /// Owned here rather than by a screen: the phone is put down and the
  /// screen disposed long before it fires. Only valid after [init].

  static SleepTimer get sleepTimer {
    assert(_sleepTimer != null, 'Player.init() must be awaited in main().');

    return _sleepTimer!;
  }

  /// The audio handler. Only valid after [init] has completed.

  static RadioAudioHandler get handler {
    assert(_handler != null, 'Player.init() must be awaited in main().');

    return _handler!;
  }

  /// Start the audio backend and the media session.
  ///
  /// The order matters. The libmpv backend must be registered before the
  /// first AudioPlayer is built; the audio session must be configured before
  /// anything plays, so the OS knows to pause other apps rather than duck
  /// them; and the cached library is pushed in last so Android Auto has a
  /// browse tree even when the app was launched by the car and nobody has
  /// logged in to a Pod yet.

  static Future<void> init() async {
    initNativeAudioBackend();

    _handler = await AudioService.init(
      builder: RadioAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: notificationChannelId,
        androidNotificationChannelName: notificationChannelName,

        // 20260921 gjw Keep the service in the foreground across a pause.
        // From Android 12 an app may not restart a foreground service from
        // the background, so letting it drop out on pause would make the
        // next Play throw ForegroundServiceStartNotAllowedException. This
        // also keeps the notification on screen while stopped, which is why
        // androidNotificationOngoing is left alone — audio_service asserts
        // that the two are not both set.
        androidStopForegroundOnPause: false,

        // 20260923 gjw Ask Android Auto for SCROLLABLE LISTS rather than
        // grids of tiles. A list shows each station's full name, fits more
        // rows on a head unit, and scrolls; a grid is only worth it when
        // every item has distinctive artwork, which internet radio does not.
        // See autoStyleList in constants/app.dart.
        androidBrowsableRootExtras: {
          'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
          'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': autoStyleList,
          'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': autoStyleList,
        },
      ),
    );

    // 20260920 gjw Radio is music, not speech: when a navigation app speaks
    // we want to duck rather than stop, and when another music app starts we
    // want to give way entirely. AudioSessionConfiguration.music() is exactly
    // that policy.

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('[Player] audio session configuration failed: $e');
    }

    // 20260929 tc Attach the CarPlay bridge BEFORE the cached library is
    // pushed in, so a car that launched the app has a station to play the
    // moment the list appears.

    CarPlayBridge.attach(_handler!);

    // The timer stops playback and nothing else — see SleepTimer. Built here
    // because the handler is what it acts on, and both outlive every screen.

    _sleepTimer = SleepTimer(() => _handler!.stop());
    _sleepTimer!.defaultDuration = await SleepPreference.load();

    final (stations, playlists) = await LocalStore.load();

    // 20261006 gjw Write the chosen station icons out HERE as well as in
    // AppProvider._pushToPlayer().
    //
    // THIS IS THE CAR'S PATH. Android Auto starts the media service on its
    // own, before any login and before AppProvider exists (CLAUDE.md §2), so
    // the library arrives straight from LocalStore and never passes through
    // _pushToPlayer. Syncing in only that one place left the cache empty
    // whenever the car started the app: StationIconCache.pathFor() returned
    // null, and a station with a chosen icon showed no artwork at all while
    // one with an https logo was fine. It looked intermittent because
    // opening the app on the phone populated the cache and hid it.

    await StationIconCache.sync(stations);

    _handler!.setLibrary(stations, playlists);
  }
}
