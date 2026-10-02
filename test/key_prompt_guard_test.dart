/// Tests for the security key prompt guard that stops the Cancel loop.
///
// Time-stamp: <Friday 2026-10-02 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
//
/// Authors: Graham Williams

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/services/app_provider.dart';

/// 20261002 gjw The bug these pin down.
///
/// solidui's security key screen is pushed fullscreen, and its Cancel runs
/// `pushReplacement(context, widget.child)` with the child being the
/// AppScaffold the prompt was asked for. Cancelling therefore built a NEW
/// AppScaffold, whose initState asked for the key again, for ever — and the
/// Pod session outlives a restart, so there was no way into the app at all.
///
/// AppScaffold cannot hold the guard, because AppScaffold is the thing being
/// rebuilt. It lives on AppProvider, which sits above MaterialApp and
/// survives the replacement. These tests are about that survival, so they
/// deliberately reuse ONE provider across the calls that a rebuild would
/// otherwise spread over several scaffold instances.

void main() {
  group('the prompt is claimed once a session', () {
    test('the first caller claims it and later callers do not', () {
      final provider = AppProvider();

      expect(provider.keyPromptShown, isFalse);
      expect(provider.claimKeyPrompt(), isTrue, reason: 'first ask');

      // The scaffold that Cancel builds, asking on the way in.

      expect(provider.claimKeyPrompt(), isFalse, reason: 'rebuilt scaffold');
      expect(provider.claimKeyPrompt(), isFalse, reason: 'and again');
      expect(provider.keyPromptShown, isTrue);
    });

    test('claimed BEFORE the prompt is awaited, so a rebuild cannot race', () {
      final provider = AppProvider();

      // The ordering is the whole point: the replacement scaffold runs while
      // the first is still suspended on the prompt. Claiming after the await
      // would let a second prompt through.

      provider.claimKeyPrompt();
      expect(provider.claimKeyPrompt(), isFalse);
    });
  });

  group('declining falls back to the device library', () {
    test('decline pins the source to local', () {
      final provider = AppProvider()..setLoggedIn(true);

      expect(provider.source, LibrarySource.pod);
      expect(provider.isLocal, isFalse);

      provider.declineKeyPrompt();

      expect(provider.keyPromptDeclined, isTrue);
      expect(provider.source, LibrarySource.local);
      expect(provider.isLocal, isTrue);
    });

    test('a later setLoggedIn cannot flip it back to the Pod', () {
      final provider = AppProvider()..declineKeyPrompt();

      // This is the loop's other half. The rebuilt scaffold calls
      // setLoggedIn(true) on its way in; before the fix that restored the
      // Pod source and every load threw "You must first set the security
      // key!" once for stations.ttl and once for playlists.ttl.

      provider.setLoggedIn(true);

      expect(provider.source, LibrarySource.local);
    });

    test('logging out still goes local, declined or not', () {
      final provider = AppProvider()..setLoggedIn(false);

      expect(provider.source, LibrarySource.local);
    });

    test('declining twice is harmless', () {
      final provider = AppProvider()
        ..declineKeyPrompt()
        ..declineKeyPrompt();

      expect(provider.keyPromptDeclined, isTrue);
      expect(provider.source, LibrarySource.local);
    });
  });

  test('an undeclined login still uses the Pod', () {
    // The guard must not cost the ordinary case. Someone who enters their
    // key gets the Pod exactly as before.

    final provider = AppProvider();

    provider.claimKeyPrompt();
    provider.setLoggedIn(true);

    expect(provider.keyPromptDeclined, isFalse);
    expect(provider.source, LibrarySource.pod);
  });
}
