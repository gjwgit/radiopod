/// Playlist file helpers — format detection and dispatch.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:radiopod/utils/m3u.dart';
import 'package:radiopod/utils/pls.dart';

/// One station as it appears in a playlist file: a display name and a URL.
///
/// A record rather than a class because that is all a playlist file carries.
/// The richer [Station] metadata (codec, bitrate, country) is only available
/// from Radio-Browser and is filled in there, not here.

typedef PlaylistEntry = ({String name, String url});

/// The playlist file formats RadioPod reads and writes.

enum PlaylistFormat {
  m3u('m3u', 'M3U'),
  pls('pls', 'PLS');

  const PlaylistFormat(this.extension, this.label);

  final String extension;
  final String label;
}

/// File extensions offered in the import file picker.
///
/// `m3u8` is the UTF-8 variant of M3U and parses identically.

const playlistExtensions = ['m3u', 'm3u8', 'pls'];

/// Guess the format of [content] from the file [name], falling back to the
/// content itself.
///
/// The extension is trusted first because it is what the user chose, but a
/// `.txt` or extension-less file dragged in from elsewhere is still readable:
/// a `[playlist]` header is unambiguous PLS, and anything else is treated as
/// M3U, whose plain form is just a list of URLs.

PlaylistFormat detectFormat(String name, String content) {
  final ext = name.toLowerCase().split('.').last;
  if (ext == 'pls') return PlaylistFormat.pls;
  if (ext == 'm3u' || ext == 'm3u8') return PlaylistFormat.m3u;

  return content.trimLeft().toLowerCase().startsWith('[playlist]')
      ? PlaylistFormat.pls
      : PlaylistFormat.m3u;
}

/// Parse [content] as [format], returning the stations it lists.

List<PlaylistEntry> parsePlaylist(String content, PlaylistFormat format) =>
    switch (format) {
      PlaylistFormat.m3u => parseM3u(content),
      PlaylistFormat.pls => parsePls(content),
    };

/// Serialise [entries] to [format].

String writePlaylist(List<PlaylistEntry> entries, PlaylistFormat format) =>
    switch (format) {
      PlaylistFormat.m3u => writeM3u(entries),
      PlaylistFormat.pls => writePls(entries),
    };

/// A display name for a URL with no name of its own.
///
/// Plain M3U files and PLS entries missing a `TitleN=` line give us nothing
/// but the stream URL, so fall back to the host, which is at least
/// recognisable, and to the whole URL if it will not parse.

String nameFromUrl(String url) {
  final host = Uri.tryParse(url)?.host ?? '';

  return host.isEmpty ? url : host;
}
