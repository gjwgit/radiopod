/// Native audio backend startup stub, for WEB builds.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0
///
/// Authors: Graham Williams

library;

/// No-op on web: just_audio plays through the browser's own audio element,
/// and the libmpv LC_NUMERIC workaround applies to native Linux only.
///
/// Present so main() can use the conditional import uniformly, without
/// pulling `dart:ffi`, `dart:io` or media_kit into a web build.

void initNativeAudioBackend() {}
