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

import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/opml.dart';
import 'package:radiopod/utils/playlist_file.dart';

/// Write [stations] as a [format] playlist to a user-chosen file.
///
/// 20261016 gjw Podcasts are left out. Their address is an RSS feed, not
/// audio, and an M3U or PLS player handed one would play nothing. They go
/// to [saveOpmlFile] instead, which is what a podcast app reads.
///
/// Returns the saved path, or null if the user cancelled. [name], the
/// playlist's, or empty for the whole library, goes into the suggested
/// filename through [exportFileName].

Future<String?> savePlaylistFile({
  required List<Station> stations,
  required String name,
  required PlaylistFormat format,
}) async {
  final content = writePlaylist([
    for (final s in stations)
      if (!s.isPodcast) (name: s.name, url: s.url),
  ], format);

  final fileUri = await FilePicker.saveFile(
    dialogTitle: 'Save ${format.label} playlist',
    fileName: exportFileName(name, format.extension),
    bytes: utf8.encode(content),
    type: FileType.custom,
    allowedExtensions: [format.extension],
  );

  return fileUri?.path;
}

/// Write [feeds] as an OPML subscription list to a user-chosen file.
///
/// Returns the saved path, or null if the user cancelled.

Future<String?> saveOpmlFile(List<OpmlFeed> feeds) async {
  final fileUri = await FilePicker.saveFile(
    dialogTitle: 'Save podcasts as OPML',
    fileName: exportFileName('podcasts', 'opml'),
    bytes: utf8.encode(writeOpml(feeds, title: 'RadioPod podcasts')),
    type: FileType.custom,
    allowedExtensions: const ['opml'],
  );

  return fileUri?.path;
}

/// The suggested name for an exported file: the app's name, then [part] if
/// any, then the date, all in lower case with single underscores, as in
/// radiopod_drive_work_20261021.m3u.
///
/// 20261021 gjw Always lower case and always dated, so exports sort
/// together in a folder and a later one never overwrites an earlier one
/// unasked.

String exportFileName(String part, String extension, {DateTime? now}) {
  final d = now ?? DateTime.now();
  final stamp =
      '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  final stem = [
    'radiopod',
    if (part.trim().isNotEmpty) safeFileName(part),
    stamp,
  ].join('_').toLowerCase().replaceAll(RegExp(r'_+'), '_');

  return '$stem.$extension';
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
