/// Player — one-time setup and global access to the audio handler.
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

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/services/library_cache.dart';
import 'package:radiopod/services/radio_audio_handler.dart';
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

        // 20260920 gjw Tells Android Auto to draw the browse tree as a grid
        // of station logos rather than a plain list.

        androidBrowsableRootExtras: {
          'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
          'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2,
          'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 2,
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

    final (stations, playlists) = await LibraryCache.load();
    _handler!.setLibrary(stations, playlists);
  }
}
