/// Tests for focusWaitStep: when to resume after another app took the sound.
///
// Time-stamp: <Friday 2026-10-23 10:00:00 +1100 Graham Williams>
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

import 'package:radiopod/services/focus_policy.dart';

void main() {
  test('waits while the other app still plays', () {
    expect(
      focusWaitStep(waited: const Duration(seconds: 10), quietPolls: 0),
      FocusWait.keepWaiting,
    );
  });

  test('one quiet look is only a gap between tracks', () {
    expect(
      focusWaitStep(waited: const Duration(seconds: 10), quietPolls: 1),
      FocusWait.keepWaiting,
    );
  });

  test('resumes after enough quiet looks in a row', () {
    expect(
      focusWaitStep(
        waited: const Duration(seconds: 10),
        quietPolls: focusQuietPolls,
      ),
      FocusWait.resume,
    );
  });

  test('gives up once the limit has passed', () {
    expect(
      focusWaitStep(waited: focusWaitLimit, quietPolls: 0),
      FocusWait.giveUp,
    );
  });

  test('silence found right at the limit still resumes', () {
    expect(
      focusWaitStep(waited: focusWaitLimit, quietPolls: focusQuietPolls),
      FocusWait.resume,
    );
  });
}
