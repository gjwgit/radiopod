/// OidcEventLog — what the native login browser actually did.
///
// Time-stamp: <Monday 2026-09-29 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:oidc/oidc.dart';

/// A short in-memory record of what happened during a login attempt, from the
/// native sign-in browser's own events and from the Dart side's `debugPrint`.
///
/// 20260929 gjw Why this exists. When a login fails, solidui can only say
/// "the login window may have been closed, or the server refused the
/// request", and it is not being vague for the sake of it: the `oidc` package
/// throws away the server's reason. Solid servers advertise RFC 9207 `iss`
/// support and then omit `iss` from error responses, so `oidc` treats the
/// reply as a possible mix-up attack and reports that instead of the original
/// error code.
///
/// The native layer underneath still knows. `oidc_darwin`
/// (ASWebAuthenticationSession on iOS and macOS) and `oidc_android` (Custom
/// Tabs) emit typed events for opening the browser, receiving the redirect,
/// the user dismissing it, and structured failures. Those events separate the
/// two possibilities the message has to lump together — a CANCELLED says the
/// person closed the sheet, a redirect carrying `error=true` says the server
/// refused.
///
/// Everything here is device-local and is never written to the Pod or sent
/// anywhere. The events are redacted at the source: the redirect event
/// carries the scheme, the host, and whether `code`, `state` and `error` were
/// present, but never the raw URI, so no authorization code can reach this
/// log.
///
/// On platforms with no native browser layer — GNU/Linux, Windows and the web
/// — `nativeBrowserEvents()` is the base implementation returning an empty
/// stream, so starting this is harmless everywhere.

class OidcEventLog {
  OidcEventLog._();

  /// The single log, read by the Settings diagnostics section.

  static final OidcEventLog instance = OidcEventLog._();

  /// Keeps the log bounded. A login flow emits a handful of events, so this
  /// holds several attempts, which is what makes "it failed the first time
  /// and worked the second" legible.

  static const maxEntries = 50;

  /// Caps one captured line, so a stack trace cannot crowd out the log.

  static const maxLineLength = 300;

  final List<String> _entries = [];

  StreamSubscription<OidcNativeBrowserEvent>? _subscription;

  bool _wrappedDebugPrint = false;

  /// True while [_add] is echoing to the console, so the `debugPrint` wrapper
  /// does not read our own output back and loop.

  bool _emitting = false;

  /// The log, oldest first.

  List<String> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  /// Subscribes to the native browser events. Safe to call more than once.
  ///
  /// Failures are swallowed into the log itself rather than thrown: this is a
  /// diagnostic, and it must never be the reason the app will not start.

  void start() {
    if (_subscription != null) return;

    try {
      _subscription = OidcPlatform.instance.nativeBrowserEvents().listen(
        (event) => _add(describe(event)),
        onError: (Object error) => _add('event stream error: $error'),
      );
    } on Object catch (error) {
      _add('could not subscribe to native events: $error');
    }

    _captureDebugPrint();
  }

  /// 20260929 gjw Also keep the Dart side's own account of a failure.
  ///
  /// The native events only exist once the browser has been asked for, and a
  /// login can fail well before that. When it does, solidpod catches EVERY
  /// exception, returns null, and reports the reason through `debugPrint`
  /// alone (`authenticate.dart:311`) — so on a TestFlight device the cause is
  /// written to a console nobody can read.
  ///
  /// `debugPrint` is a mutable function reference, so wrapping it here copies
  /// those lines into this log on the way past. Release builds still run it,
  /// which is the point: this has to work in the build the tester has.
  ///
  /// Only lines matching [shouldCapture] are kept, so this stays a login log
  /// rather than a transcript of the whole app.

  void _captureDebugPrint() {
    if (_wrappedDebugPrint) return;

    _wrappedDebugPrint = true;

    final inner = debugPrint;

    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && !_emitting && shouldCapture(message)) {
        _add(
          message.length > maxLineLength
              ? '${message.substring(0, maxLineLength)}…'
              : message,
        );
      }

      inner(message, wrapWidth: wrapWidth);
    };
  }

  /// Whether a `debugPrint` line is about logging in.
  ///
  /// Deliberately a small list. A diagnostic the user is invited to paste into
  /// a bug report should not quietly accumulate everything the app ever
  /// printed.

  @visibleForTesting
  static bool shouldCapture(String message) {
    final text = message.toLowerCase();

    return const [
      'solid',
      'oidc',
      'authenticate',
      'keychain',
      'securestorage',
      'secure storage',

      // Spelt out rather than matching 'session', which would drag in every
      // audio_session line and drown the log in playback chatter.
      'restoresession',
    ].any(text.contains);
  }

  /// Clears the log, so a tester can retry and capture just that attempt.

  void clear() => _entries.clear();

  void _add(String line) {
    final at = DateTime.now().toIso8601String().substring(11, 19);

    _entries.add('$at  $line');

    if (_entries.length > maxEntries) _entries.removeAt(0);

    // Also to the console, for a device that happens to be attached. The
    // flag stops the wrapper above copying our own line straight back in.

    _emitting = true;
    debugPrint('oidc: $line');
    _emitting = false;
  }

  /// Renders one event as a line a person can read.
  ///
  /// Visible for testing, and because the wording is the point: the tester
  /// reads this, not a developer.

  @visibleForTesting
  static String describe(OidcNativeBrowserEvent event) => switch (event) {
    OidcBrowserOpeningEvent() => 'opening the sign-in browser',
    OidcBrowserOpenedEvent(:final sessionType, :final captureMode) =>
      'browser opened — ${sessionType.name} session, '
          'redirect captured by ${captureMode.name}',
    OidcBrowserRedirectReceivedEvent(
      :final scheme,
      :final host,
      :final hasCode,
      :final hasState,
      :final hasError,
    ) =>
      'redirect received on ${scheme ?? '?'}://${host ?? ''} — '
          'code=$hasCode state=$hasState error=$hasError',
    OidcBrowserFlowCancelledEvent() =>
      'CANCELLED — the sign-in sheet was dismissed before it finished',
    OidcBrowserFlowFailedEvent(:final error) => _describeFailure(error),
    OidcBrowserNativeWarningEvent(:final code) => 'warning: $code',
  };

  static String _describeFailure(OidcNativeError error) {
    final buffer = StringBuffer('FAILED — ${error.kind.name}');

    if (error.nativeDomain != null || error.nativeCode != null) {
      buffer.write(
        ' (${error.nativeDomain ?? '?'} ${error.nativeCode ?? '?'})',
      );
    }

    if (error.message != null) buffer.write(': ${error.message}');

    return buffer.toString();
  }
}
