/// Driver for the App Store screenshot run — writes each capture to disk.
///
// Time-stamp: <Tuesday 2026-09-30 06:00:00 +1000 Graham Williams>
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

import 'package:integration_test/integration_test_driver_extended.dart';

/// 20260930 gjw Runs on the HOST, not the device.
///
/// `binding.takeScreenshot()` in the test hands the PNG bytes back over the
/// driver extension, and this writes them where the workflow can upload
/// them. Nothing here touches the device.
///
/// SCREENSHOT_DIR lets the workflow give each simulator its own folder, so
/// an iPad run does not overwrite an iPhone one. It defaults to a plain
/// `screenshots/` for a run by hand.

Future<void> main() async {
  final dir = Platform.environment['SCREENSHOT_DIR'] ?? 'screenshots';

  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          final file = File('$dir/$name.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes);

          stdout.writeln('wrote ${file.path} (${bytes.length} bytes)');

          // Returning false fails the test. This callback only stores the
          // image — it is not comparing against a baseline — so it always
          // succeeds.

          return true;
        },
  );
}
