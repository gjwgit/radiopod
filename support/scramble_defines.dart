// Scramble the Podcast Index key and secret for a build.
//
// Time-stamp: <Friday 2026-10-16 06:00:00 +1100 Graham Williams>
//
// Copyright (C) 2026, Togaware Pty Ltd
//
// Licensed under the GNU General Public License, Version 3 (the "License").
//
// License: https://opensource.org/license/gpl-3-0
//
// Authors: Graham Williams
//
// 20261016 gjw Run from the repository root, after `flutter pub get`:
//
//     dart run support/scramble_defines.dart
//
// Reads PODCAST_INDEX_KEY and PODCAST_INDEX_SECRET from the environment if
// set (as CI does, from its secrets), otherwise from dart_defines.json, and
// rewrites dart_defines.json with only the scrambled PODCAST_INDEX_KEY_X and
// PODCAST_INDEX_SECRET_X that the app reads. The plain values are removed
// from the file. Safe to run twice. Never prints a value.

import 'dart:convert';
import 'dart:io';

import 'package:radiopod/utils/scramble.dart';

const _file = 'dart_defines.json';
const _names = ['PODCAST_INDEX_KEY', 'PODCAST_INDEX_SECRET'];

void main() {
  final file = File(_file);
  final defines = file.existsSync()
      ? (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
      : <String, dynamic>{};

  var changed = 0;
  for (final name in _names) {
    final plain = Platform.environment[name] ?? defines[name] as String?;
    defines.remove(name);
    if (plain == null || plain.trim().isEmpty) continue;

    defines['${name}_X'] = scramble(plain.trim());
    changed++;
    stdout.writeln('$name: scrambled (${plain.trim().length} characters)');
  }

  if (changed == 0) {
    final ready = _names.every((n) => defines.containsKey('${n}_X'));
    stdout.writeln(
      ready
          ? '$_file is already scrambled; nothing to do.'
          : 'No plain $_names found in the environment or $_file. Podcast '
                'search will be unavailable in the build.',
    );
  }

  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(defines)}\n',
  );
}
