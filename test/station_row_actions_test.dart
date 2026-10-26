/// Tests for when a station row shows buttons rather than a menu.
///
// Time-stamp: <Wednesday 2026-10-08 11:00:00 +1100 Graham Williams>
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
  // 20261008 gjw A phone keeps the three dot menu; a desktop window gets the
  // three actions as buttons. 20261026 gjw Even a narrow one: see
  // rowButtonsMinWidth.

  test('a phone keeps the menu', () {
    expect(rowShowsButtons(400), isFalse);
  });

  test('a desktop window gets the buttons', () {
    expect(rowShowsButtons(1280), isTrue);
  });

  test('so does a narrow desktop window, at 600', () {
    expect(rowShowsButtons(600), isTrue);
  });

  test('a large phone held upright keeps the menu', () {
    expect(rowShowsButtons(430), isFalse);
  });

  test('the switch is at rowButtonsMinWidth', () {
    const t = rowButtonsMinWidth;

    expect(rowShowsButtons(t - 1), isFalse);
    expect(rowShowsButtons(t), isTrue, reason: 'inclusive at the threshold');
  });

  test('a zero width is treated as narrow rather than throwing', () {
    expect(rowShowsButtons(0), isFalse);
  });
}
