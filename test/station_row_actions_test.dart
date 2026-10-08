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
import 'package:solidui/solidui.dart' show NavigationConstants;

import 'package:radiopod/screens/stations_screen.dart';

void main() {
  // 20261008 gjw A phone keeps the three dot menu; a desktop window gets the
  // three actions as buttons. The point of pinning it is that the row and
  // the navigation must change at the SAME width — see rowShowsButtons.

  test('a phone keeps the menu', () {
    expect(rowShowsButtons(400), isFalse);
  });

  test('a desktop window gets the buttons', () {
    expect(rowShowsButtons(1280), isTrue);
  });

  test('the switch is solidui s own narrow threshold, not a local guess', () {
    const t = NavigationConstants.narrowScreenThreshold;

    expect(rowShowsButtons(t - 1), isFalse);
    expect(rowShowsButtons(t), isTrue, reason: 'inclusive at the threshold');
  });

  test('a zero width is treated as narrow rather than throwing', () {
    expect(rowShowsButtons(0), isFalse);
  });
}
