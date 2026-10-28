/// Tests for when a station row shows a Delete button.
///
// Time-stamp: <Wednesday 2026-10-28 15:00:00 +1100 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
//
/// Authors: Graham Williams

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/screens/stations_screen.dart';

void main() {
  // 20261008 gjw A phone has the Information button alone and deletes with
  // a swipe; a desktop window adds a Delete button. 20261026 gjw Even a
  // narrow one: see rowDeleteMinWidth.

  test('a phone has no Delete button', () {
    expect(rowShowsDelete(400), isFalse);
  });

  test('a desktop window gets one', () {
    expect(rowShowsDelete(1280), isTrue);
  });

  test('so does a narrow desktop window, at 600', () {
    expect(rowShowsDelete(600), isTrue);
  });

  test('a large phone held upright has none', () {
    expect(rowShowsDelete(430), isFalse);
  });

  test('the switch is at rowDeleteMinWidth', () {
    const t = rowDeleteMinWidth;

    expect(rowShowsDelete(t - 1), isFalse);
    expect(rowShowsDelete(t), isTrue, reason: 'inclusive at the threshold');
  });

  test('a zero width is treated as narrow rather than throwing', () {
    expect(rowShowsDelete(0), isFalse);
  });
}
