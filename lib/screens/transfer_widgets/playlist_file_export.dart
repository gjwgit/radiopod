/// Playlist file export — write an M3U or PLS file to a chosen location.
///
/// Wraps the file-picker save dialog, which writes the bytes itself,
/// returning the saved path (or null if cancelled) so the calling screen can
/// show an appropriate status message. Kept separate to keep the Transfer
/// screen focused on layout and state.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/playlist_file.dart';

/// Write [stations] as a [format] playlist to a user-chosen file.
///
/// Returns the saved path, or null if the user cancelled. [name] seeds the
/// suggested filename, sanitised so a playlist called "Drive / Work" cannot
/// produce a path separator.

Future<String?> savePlaylistFile({
  required List<Station> stations,
  required String name,
  required PlaylistFormat format,
}) async {
  final content = writePlaylist(
    [for (final s in stations) (name: s.name, url: s.url)],
    format,
  );

  final fileUri = await FilePicker.saveFile(
    dialogTitle: 'Save ${format.label} playlist',
    fileName: '${safeFileName(name)}.${format.extension}',
    bytes: utf8.encode(content),
    type: FileType.custom,
    allowedExtensions: [format.extension],
  );

  return fileUri?.path;
}

/// Reduce [name] to something safe to put in a filename.
///
/// Anything that is not a letter, digit, dash or underscore becomes an
/// underscore, so path separators, colons and quotes can never reach the
/// save dialog. An empty result falls back to the app name rather than
/// producing a file called just ".m3u".

String safeFileName(String name) {
  final safe = name
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9\-_ ]'), '_')
      .replaceAll(RegExp(r'\s+'), '_');

  return safe.isEmpty ? 'radiopod' : safe;
}
