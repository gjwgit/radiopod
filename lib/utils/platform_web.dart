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

/// False on web. The browser audio element reports no ICY metadata, but
/// reading the stream separately is not an option either: a station's server
/// will not send CORS headers, so the fetch is blocked. Web shows the
/// station's own details instead of a track title.

bool get needsIcyPolling => false;

/// False on web: Stop tears the player down rather than pausing.
///
/// The browser gives just_audio ONE shared audio element. Pausing leaves the
/// old stream loaded in it, and loading the next station then waits on a
/// `durationchange` event that a live stream may never fire — the next
/// station showed "Connecting…" indefinitely while the previous one could
/// still be heard. See the io version for the platforms that do pause.

bool get stopByPause => false;

/// No-op on web: just_audio plays through the browser's own audio element,
/// and the libmpv LC_NUMERIC workaround applies to native Linux only.
///
/// Present so main() can use the conditional import uniformly, without
/// pulling `dart:ffi`, `dart:io` or media_kit into a web build.

void initNativeAudioBackend() {}
