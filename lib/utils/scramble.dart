/// Scramble — keep a build-time secret out of the binary as plain text.
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

import 'dart:convert';

/// The mask a secret is XORed with. Arbitrary bytes; changing them means
/// re-scrambling every secret with `dart run support/scramble_defines.dart`.

const _mask = [
  0x02, 0x27, 0x10, 0xfb, 0x9c, 0x2a, 0xe9, 0xf2, 0xe8, 0xb2, 0x16, 0x22, //
  0x76, 0x17, 0x79, 0xc3, 0x8b, 0x08, 0x3d, 0x13, 0x41, 0x01, 0xec, 0x50,
  0xbd, 0x87, 0x34, 0xbf, 0xfd, 0x4f, 0xed, 0x7f,
];

/// [plain] XORed with the mask and base64 encoded, for a `--dart-define`.
///
/// 20261016 gjw NOT ENCRYPTION. A value passed with `--dart-define` is
/// compiled into the app as a string constant, and anyone can list a
/// binary's strings. Passing it scrambled means the Podcast Index secret
/// never appears there as itself; unscrambling it takes reading the code,
/// which an obfuscated release build makes slower still. That raises the
/// bar from a one-line `strings` to real effort, which is all a secret that
/// ships inside an app can have. See CLAUDE.md §16.

String scramble(String plain) {
  final bytes = utf8.encode(plain);

  return base64.encode([
    for (var i = 0; i < bytes.length; i++) bytes[i] ^ _mask[i % _mask.length],
  ]);
}

/// The plain value of a [scramble]d one, or empty for empty or rubbish.

String unscramble(String scrambled) {
  if (scrambled.isEmpty) return '';
  try {
    final bytes = base64.decode(scrambled);

    return utf8.decode([
      for (var i = 0; i < bytes.length; i++) bytes[i] ^ _mask[i % _mask.length],
    ]);
  } on FormatException {
    return '';
  }
}
