/// Tests for OidcEventLog's rendering of native sign-in browser events.
///
// Time-stamp: <Monday 2026-09-29 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:oidc/oidc.dart';

import 'package:radiopod/services/oidc_event_log.dart';

void main() {
  final at = DateTime(2026, 9, 29, 11, 42);

  // 20260929 gjw The whole point of the log is telling the two failures
  // apart, so those are the cases named here. A dismissed sheet and a server
  // refusal both end as the same "sign-in did not complete" message in the
  // UI; these lines are what distinguishes them afterwards.

  group('describe', () {
    test('a dismissed sheet reads as cancelled', () {
      final line = OidcEventLog.describe(OidcBrowserFlowCancelledEvent(at: at));

      expect(line, contains('CANCELLED'));
      expect(line, contains('dismissed'));
    });

    test('a refused authorization shows error=true on the redirect', () {
      final line = OidcEventLog.describe(
        OidcBrowserRedirectReceivedEvent(
          at: at,
          scheme: 'com.togaware.radiopod',
          host: 'redirect',
          hasError: true,
        ),
      );

      expect(line, contains('com.togaware.radiopod'));
      expect(line, contains('error=true'));
      expect(line, contains('code=false'));
    });

    test('a successful redirect carries a code', () {
      final line = OidcEventLog.describe(
        OidcBrowserRedirectReceivedEvent(
          at: at,
          scheme: 'com.togaware.radiopod',
          hasCode: true,
          hasState: true,
        ),
      );

      expect(line, contains('code=true'));
      expect(line, contains('error=false'));
    });

    test('a native failure keeps the platform domain and code', () {
      final line = OidcEventLog.describe(
        OidcBrowserFlowFailedEvent(
          at: at,
          error: const OidcNativeError(
            kind: OidcNativeErrorKind.presentationContextNotProvided,
            nativeDomain: 'ASWebAuthenticationSessionErrorDomain',
            nativeCode: 2,
            message: 'No presentation context',
          ),
        ),
      );

      expect(line, startsWith('FAILED'));
      expect(line, contains('presentationContextNotProvided'));
      expect(line, contains('ASWebAuthenticationSessionErrorDomain'));
      expect(line, contains('2'));
      expect(line, contains('No presentation context'));
    });

    test('an opened browser names the session and capture mode', () {
      final line = OidcEventLog.describe(
        OidcBrowserOpenedEvent(
          at: at,
          sessionType: OidcNativeSessionType.ephemeral,
          captureMode: OidcRedirectCaptureMode.asWebAuthenticationSession,
        ),
      );

      expect(line, contains('ephemeral'));
      expect(line, contains('asWebAuthenticationSession'));
    });
  });

  // 20260929 gjw The Dart side is where a login that never opens a browser
  // fails, and solidpod reports it through debugPrint and nowhere else. These
  // name the real lines it emits.

  group('shouldCapture', () {
    test('keeps solidpod\'s own report of a failed login', () {
      expect(
        OidcEventLog.shouldCapture(
          'Solid Authenticate Failed: Exception: something went wrong',
        ),
        isTrue,
      );
      expect(
        OidcEventLog.shouldCapture('tryRestoreSession failed: bad token'),
        isTrue,
      );
      expect(
        OidcEventLog.shouldCapture('solidpod: keychain using the legacy one'),
        isTrue,
      );
    });

    test('keeps the oidc packages', () {
      expect(
        OidcEventLog.shouldCapture('oidc_darwin: failed to launch the url'),
        isTrue,
      );
    });

    test('ignores unrelated chatter', () {
      expect(OidcEventLog.shouldCapture('MPV: cache-on-disk'), isFalse);
      expect(
        OidcEventLog.shouldCapture('Another exception was thrown'),
        isFalse,
      );
    });
  });

  // The redirect event is redacted at the source, but assert it here too: a
  // log the user is invited to paste into a bug report must never be able to
  // carry an authorization code.

  test('no raw redirect URI or code value can reach the log', () {
    final line = OidcEventLog.describe(
      OidcBrowserRedirectReceivedEvent(
        at: at,
        scheme: 'com.togaware.radiopod',
        host: 'redirect',
        hasCode: true,
        hasState: true,
      ),
    );

    expect(line, isNot(contains('?')));
    expect(line.split(' '), isNot(contains(matches(r'^[A-Za-z0-9_-]{20,}$'))));
  });
}
