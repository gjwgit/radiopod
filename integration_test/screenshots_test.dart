/// Drives the app through the screens the App Store listing shows.
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

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:radiopod/main.dart' as app;
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/local_store.dart';

/// 20260930 gjw Screenshots for the App Store, captured on a simulator.
///
/// This test asserts almost nothing. It exists to put the app in a known
/// state, walk it through the screens, and capture each one.
///
/// THE CAPTURE IS THE BINDING'S, not `xcrun simctl`'s. On iOS
/// `integration_test`'s native `capturePngScreenshot` renders every visible
/// window over the whole of `scene.screen.bounds` at native scale, so the
/// PNG comes out at the device's exact pixel dimensions — which is what
/// Apple requires — and it includes the status bar. Being a call inside the
/// test, it also happens exactly when the screen is ready, with no race
/// against an external process watching stdout.
///
/// `test_driver/integration_test.dart` writes the bytes to disk on the host.
///
/// Run it by hand against a booted simulator with
///
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart \
///     -d `<udid>`
///
/// WARNING. This SEEDS THE DEVICE'S LOCAL LIBRARY, overwriting whatever
/// stations and playlists are stored there (`LocalStore`, the `cached_*`
/// SharedPreferences keys). On a fresh simulator that is free. Do not point
/// it at a device or desktop whose library you care about.

/// A small library, so the screens are not photographed empty.
///
/// Real stations at REACHABLE addresses. A screenshot carrying invented
/// names would misrepresent the app, and an invented URL would be worse: the
/// repository's link checker reads this file and fails on one, which is how
/// the first pass at this list was caught. Every address below was confirmed
/// to answer before being added, and the codec follows from the URL rather
/// than being guessed.
///
/// The list order is the order the Stations screen shows — see CLAUDE.md §5,
/// the list order is the user's order and nothing re-sorts it.

const _stations = [
  Station(
    id: 'shot-1',
    name: '2GB Sydney',
    // NOT split across two string literals, however long it is: the link
    // checker reads this file as text and would see only the first half,
    // then fail on a URL that does not exist.
    url: 'https://playerservices.streamtheworld.com/api/livestream-redirect/2GB.mp3',
    country: 'Australia',
    codec: 'MP3',
  ),
  Station(
    id: 'shot-2',
    name: 'BBC World Service',
    url: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service',
    country: 'United Kingdom',
    codec: 'MP3',
  ),
  Station(
    id: 'shot-3',
    name: 'Classic FM',
    url: 'https://ice-the.musicradio.com/ClassicFMMP3',
    country: 'United Kingdom',
    codec: 'MP3',
  ),
  Station(
    id: 'shot-4',
    name: 'Radio Paradise',
    url: 'https://stream.radioparadise.com/aac-320',
    country: 'United States',
    codec: 'AAC',
    bitrate: 320,
  ),
  Station(
    id: 'shot-5',
    name: 'FIP',
    url: 'https://icecast.radiofrance.fr/fip-hifi.aac',
    country: 'France',
    codec: 'AAC',
  ),
];

const _playlists = [
  Playlist(id: 'pl-1', name: 'Talk and News', stationIds: ['shot-1', 'shot-2']),
  Playlist(
    id: 'pl-2',
    name: 'Music',
    stationIds: ['shot-3', 'shot-4', 'shot-5'],
  ),
];

Future<void> _shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pumpAndSettle();

  // A beat for anything that settles outside the widget tree — a station
  // logo arriving over the network, say. pumpAndSettle does not wait for
  // that, and a half-drawn image in a store screenshot looks like a fault.

  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));

  await tester.pumpAndSettle();
  await binding.takeScreenshot(name);
}

Future<void> _openMenu(WidgetTester tester, IconData icon) async {
  final target = find.byIcon(icon);

  expect(
    target,
    findsWidgets,
    reason:
        'No $icon in the navigation. The menu is built from SolidMenuItems '
        'in app_scaffold.dart — if the icons there changed, change them '
        'here too.',
  );

  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walk the screens for the store listing', (tester) async {
    // Seed BEFORE the app starts, so the first frame already has content.
    // LocalStore is the library when nobody is logged in (CLAUDE.md §4), so
    // writing it here is all the setup a fresh simulator needs.

    await LocalStore.save(_stations, _playlists);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Tapping Continue is a supported way to run RadioPod, and it is the
    // only way through the login screen without a Pod on a CI runner.

    final continueButton = find.text('Continue');

    expect(
      continueButton,
      findsWidgets,
      reason:
          'No Continue button on the login screen — has solidui renamed '
          'it? Without this the run cannot reach the app at all.',
    );

    await tester.tap(continueButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await _shot(binding, tester, '01-stations');

    await _openMenu(tester, Icons.search);
    await _shot(binding, tester, '02-search');

    await _openMenu(tester, Icons.queue_music);
    await _shot(binding, tester, '03-playlists');

    await _openMenu(tester, Icons.save_alt);
    await _shot(binding, tester, '04-transfer');

    await _openMenu(tester, Icons.settings);
    await _shot(binding, tester, '05-settings');
  });
}
