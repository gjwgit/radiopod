/// M3U / M3U8 playlist reading and writing.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:radiopod/utils/playlist_file.dart';

/// Parse an M3U or M3U8 playlist.
///
/// The extended form pairs a `#EXTINF:<seconds>,<name>` line with the URL on
/// the following non-comment line:
///
///     #EXTM3U
///     #EXTINF:-1,ABC Classic
///     https://live-radio01.mediahubaustralia.com/2FMW/mp3/
///
/// The plain form is a bare list of URLs with no `#EXTINF` at all, so a
/// pending name is optional and [nameFromUrl] supplies one when it is
/// missing. Any other `#` line — `#EXTM3U`, `#PLAYLIST`, a comment — is
/// skipped. Attributes that some writers place before the comma
/// (`#EXTINF:-1 tvg-logo="x",Name`) are dropped with the duration, since
/// everything after the FIRST comma is the name.

List<PlaylistEntry> parseM3u(String content) {
  final entries = <PlaylistEntry>[];
  String? pendingName;

  for (final raw in content.split(RegExp(r'\r\n|\r|\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#')) {
      if (line.toUpperCase().startsWith('#EXTINF:')) {
        final comma = line.indexOf(',');
        final name = comma >= 0 ? line.substring(comma + 1).trim() : '';
        pendingName = name.isEmpty ? null : name;
      }

      continue;
    }

    entries.add((name: pendingName ?? nameFromUrl(line), url: line));
    pendingName = null;
  }

  return entries;
}

/// Serialise [entries] as an extended M3U playlist.
///
/// A duration of -1 marks a stream of unknown length, which is what every
/// live radio station is. Newlines in a station name would corrupt the file,
/// so they are flattened to spaces.

String writeM3u(List<PlaylistEntry> entries) {
  final buf = StringBuffer('#EXTM3U\n');
  for (final e in entries) {
    buf.writeln('#EXTINF:-1,${_flatten(e.name)}');
    buf.writeln(e.url);
  }

  return buf.toString();
}

String _flatten(String s) => s.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();
