/// Tests for scrambling build-time secrets.
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

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/utils/scramble.dart';

void main() {
  test('round-trips, symbols and all', () {
    const secret = r'yzJe2eE7XV-3eY576dyRZ6wXyAbdxHkBaJ#fGxv^';

    expect(unscramble(scramble(secret)), secret);
  });

  test('the scrambled form does not contain the secret', () {
    const secret = 'ABCDEFGHIJKLMNOPQRST';
    final s = scramble(secret);

    expect(s, isNot(contains(secret)));
    expect(s, isNot(contains('ABCDEF')));
  });

  test('empty and rubbish unscramble to empty', () {
    expect(unscramble(''), '');
    expect(unscramble('not base64 at all!'), '');
  });
}
