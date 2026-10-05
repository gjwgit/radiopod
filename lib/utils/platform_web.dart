/// Native audio backend startup stub, for WEB builds.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <https://opensource.org/license/gpl-3-0>.
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

/// False on the web for a different reason than the desktop: CORS.
///
/// 20261005 gjw audio_service fetches artwork BYTES through
/// flutter_cache_manager, and station artwork is an arbitrary third-party URL
/// that essentially never sends Access-Control-Allow-Origin — the same wall
/// that forces WebHtmlElementStrategy.fallback on the station list
/// (CLAUDE.md §13). So nearly every fetch fails and prints a stack trace.

bool get showsMediaArt => false;

/// No-op on web: just_audio plays through the browser's own audio element,
/// and the libmpv LC_NUMERIC workaround applies to native Linux only.
///
/// Present so main() can use the conditional import uniformly, without
/// pulling `dart:ffi`, `dart:io` or media_kit into a web build.

void initNativeAudioBackend() {}
