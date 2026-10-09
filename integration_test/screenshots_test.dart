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

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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

/// 20261001 gjw Settle, with a BOUNDED wait.
///
/// pumpAndSettle's first argument is the INTERVAL BETWEEN PUMPS, not a
/// timeout — its timeout is the third argument and defaults to TEN MINUTES.
/// Two calls written as `pumpAndSettle(Duration(seconds: 10))`, meaning to
/// wait up to ten seconds, instead pumped in ten-second steps for up to
/// twenty minutes between them, and the iPhone leg burned its whole 30
/// minute step allowance before being killed.
///
/// Thirty seconds is generous for a screen that is only laying out, and a
/// screen that has not settled by then is a fault worth failing on rather
/// than waiting out.

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 30),
);

Future<void> _shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await _settle(tester);

  // A beat for anything that settles outside the widget tree — a station
  // logo arriving over the network, say. pumpAndSettle does not wait for
  // that, and a half-drawn image in a store screenshot looks like a fault.

  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));

  await _settle(tester);
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
  await _settle(tester);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walk the screens for the store listing', (tester) async {
    // Seed BEFORE the app starts, so the first frame already has content.
    // LocalStore is the library when nobody is logged in (CLAUDE.md §4), so
    // writing it here is all the setup a fresh simulator needs.

    await LocalStore.save(_stations, _playlists);

    app.main();
    await _settle(tester);

    // 20261010 gjw THE LOGIN PAGE IS USUALLY NOT THERE ANY MORE, and this
    // step used to insist on it.
    //
    // RadioPod sets `skipLogin: true`, and from solidui 1.4.5 that is
    // honoured properly: the login page is never built, so the run lands
    // straight in the app. Until then it was drawn for a few frames before
    // being replaced — a bug, but one this test depended on. Fixing the
    // flash broke the walk with
    //
    //     Found 0 widgets with text "Continue"
    //
    // Both paths have to work. Skipping is a device preference the user can
    // turn off from the settings dialogue, and a runner where it is off must
    // still reach the app, so Continue is tapped WHEN IT IS THERE rather
    // than required.

    final continueButton = find.text('Continue');

    if (continueButton.evaluate().isNotEmpty) {
      await tester.tap(continueButton.first);
      await _settle(tester);
    }

    // Either way the app itself must now be on screen. Checking for the
    // Stations filter box rather than for the absence of the login page:
    // this fails loudly if the walk is stuck anywhere at all, which is what
    // the old expect was really guarding.

    expect(
      find.text('Filter your stations'),
      findsWidgets,
      reason:
          'The app did not open. Either the login page was shown and its '
          'Continue button has been renamed, or start-up stopped before the '
          'Stations screen.',
    );

    // 20261001 gjw Android captures differently from iOS and has to be told
    // first. takeScreenshot() there reads back a surface that is not
    // readable until convertFlutterSurfaceToImage() has swapped it for an
    // image view; without this it throws
    //
    //   Call convertFlutterSurfaceToImage() before taking a screenshot
    //
    // (integration_test/lib/src/_callback_io.dart). The binding reverts it
    // on tear-down by itself. It is a no-op on every other platform, but
    // guarded anyway so the intent is plain.

    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await _settle(tester);
    }

    await _shot(binding, tester, 'stations');

    await _openMenu(tester, Icons.search);
    await _shot(binding, tester, 'search');

    await _openMenu(tester, Icons.queue_music);
    await _shot(binding, tester, 'playlists');

    await _openMenu(tester, Icons.save_alt);
    await _shot(binding, tester, 'export_import');

    await _openMenu(tester, Icons.settings);
    await _shot(binding, tester, 'settings');
  });
}
