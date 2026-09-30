/// RadioPcm — a station's audio as 16 kHz mono samples, for captions.
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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens a station's stream on a connection of its own and decodes it.
///
/// Deliberately free of `dart:io`, so importing it cannot break a web build;
/// the platform test uses [defaultTargetPlatform] instead.

class RadioPcm {
  RadioPcm._();

  /// The rate every sample is delivered at, which is what the speech models
  /// are trained on.

  static const sampleRate = 16000;

  static const _samples = EventChannel('radio_pcm/samples');
  static const _methods = MethodChannel('radio_pcm/methods');

  /// True where a native decoder exists: iOS and macOS, through
  /// AudioToolbox.

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// The audio of [url], as a stream of mono Float32 chunks.
  ///
  /// Only one stream may be open at a time; listening again replaces the
  /// previous one. Errors arrive as [PlatformException]s whose message is
  /// fit to show the listener. The stream is done when the station ends its
  /// broadcast.

  static Stream<Float32List> open(String url) => _samples
      .receiveBroadcastStream({'url': url, 'sampleRate': sampleRate})
      .map((event) => event as Float32List);

  /// Keep [path] out of the device backup. Quietly does nothing where that
  /// is not supported.

  static Future<void> excludeFromBackup(String path) async {
    if (!isSupported) return;
    try {
      await _methods.invokeMethod<void>('excludeFromBackup', {'path': path});
    } on PlatformException catch (e) {
      debugPrint('[RadioPcm] could not exclude $path from backup: $e');
    }
  }
}
