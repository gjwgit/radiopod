/// Native audio backend startup, for NATIVE (non-web) platforms.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0
///
/// The LC_NUMERIC workaround below is lifted from geopod, which hit the same
/// libmpv abort through video_player_media_kit. just_audio_media_kit uses the
/// same libmpv, so the fix carries over unchanged.
///
/// Authors: Graham Williams

library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

// C: char* setlocale(int category, const char* locale);

typedef _SetLocaleC = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef _SetLocaleDart = Pointer<Utf8> Function(int, Pointer<Utf8>);

// LC_NUMERIC category value on glibc (Linux).

const int _lcNumeric = 1;

/// Register the libmpv playback backend on Linux and Windows.
///
/// just_audio has no native implementation on those two desktops, so
/// just_audio_media_kit supplies one. Android, iOS and macOS use just_audio's
/// own native players and must NOT be enabled here — the media_kit native
/// libs for them are deliberately not in pubspec.yaml.
///
/// Must run before the first AudioPlayer is constructed, which is why main()
/// calls it before AudioService.init().

void initNativeAudioBackend() {
  if (!Platform.isLinux && !Platform.isWindows) return;

  _fixNumericLocale();
  JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
}

/// True where just_audio reports no ICY metadata, so RadioPod has to read the
/// song on air out of the stream itself.
///
/// just_audio_media_kit hardcodes `icyMetadata: null`, so Linux and Windows
/// would otherwise never show a track title. Android, iOS and macOS get it
/// from the player and must NOT poll — a second connection there would waste
/// mobile data for nothing. See [IcyReader].

bool get needsIcyPolling => Platform.isLinux || Platform.isWindows;

/// Whether Stop should PAUSE the player rather than tear it down.
///
/// True only where libmpv is the backend, which is the same pair of
/// platforms as [needsIcyPolling] and for the same underlying reason: those
/// are the builds just_audio drives through media_kit rather than natively.
///
/// There, disposing the player on Stop is slow enough to leave the button
/// looking dead, and is a likely source of the crash on quit — so Stop
/// pauses and the next Play re-opens the URL.
///
/// EVERYWHERE ELSE STOP MUST REALLY STOP. On the web the audio element is a
/// single shared object: a paused element still holds the old stream, and
/// loading a new URL into it waits on a `durationchange` event that a live
/// stream, having no duration, may never fire — so the next station sat on
/// "Connecting…" for ever while the previous one was still audible. A real
/// stop resets the element, which is also the honest behaviour for a radio:
/// a stopped station should not keep its connection open.

bool get stopByPause => Platform.isLinux || Platform.isWindows;

/// Force the C locale for numeric formatting on Linux.
///
/// libmpv aborts the process with "Non-C locale detected" when LC_NUMERIC is
/// anything other than "C", because it relies on '.' as the decimal
/// separator. Systems with e.g. en_AU.UTF-8 trigger this. Calling
/// setlocale(LC_NUMERIC, "C") via libc before media_kit initialises avoids
/// the crash.
///
/// Note that libmpv itself is a per-machine prerequisite on Linux:
/// `sudo apt install libmpv-dev mpv`.

void _fixNumericLocale() {
  if (!Platform.isLinux) return;

  try {
    final libc = DynamicLibrary.open('libc.so.6');
    final setlocale = libc.lookupFunction<_SetLocaleC, _SetLocaleDart>(
      'setlocale',
    );
    final c = 'C'.toNativeUtf8();
    try {
      setlocale(_lcNumeric, c);
    } finally {
      malloc.free(c);
    }
  } catch (_) {
    // If libc/setlocale is unavailable for any reason, leave the locale as is.
  }
}
