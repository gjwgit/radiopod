/// PLS playlist reading and writing.
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

/// Parse a PLS playlist.
///
/// PLS is an INI file whose entries are numbered, and the numbers need be
/// neither contiguous nor sorted:
///
///     [playlist]
///     NumberOfEntries=1
///     File1=https://stream.example/live
///     Title1=Example FM
///     Length1=-1
///     Version=2
///
/// Entries are collected by their index and emitted in ascending index
/// order, so a file that lists `File2` before `File1` still round-trips in
/// the right order. `NumberOfEntries` is deliberately ignored on read — the
/// entries actually present are authoritative, and a stale count is a common
/// defect in hand-edited files. Keys are matched case-insensitively because
/// writers disagree on `File1` versus `file1`.

List<PlaylistEntry> parsePls(String content) {
  final urls = <int, String>{};
  final titles = <int, String>{};
  final entry = RegExp(r'^(file|title)(\d+)\s*=\s*(.*)$', caseSensitive: false);

  for (final raw in content.split(RegExp(r'\r\n|\r|\n'))) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('[') || line.startsWith(';')) continue;

    final m = entry.firstMatch(line);
    if (m == null) continue;

    final index = int.parse(m.group(2)!);
    final value = m.group(3)!.trim();
    if (value.isEmpty) continue;

    if (m.group(1)!.toLowerCase() == 'file') {
      urls[index] = value;
    } else {
      titles[index] = value;
    }
  }

  final indices = urls.keys.toList()..sort();

  return [
    for (final i in indices)
      (
        name: (titles[i]?.isNotEmpty ?? false)
            ? titles[i]!
            : nameFromUrl(urls[i]!),
        url: urls[i]!,
      ),
  ];
}

/// Serialise [entries] as a version 2 PLS playlist.
///
/// Indices are 1-based and contiguous. A length of -1 marks a stream of
/// unknown duration, which is what every live radio station is.

String writePls(List<PlaylistEntry> entries) {
  final buf = StringBuffer('[playlist]\n');
  for (var i = 0; i < entries.length; i++) {
    final n = i + 1;
    buf.writeln('File$n=${entries[i].url}');
    buf.writeln('Title$n=${_flatten(entries[i].name)}');
    buf.writeln('Length$n=-1');
  }
  buf.writeln('NumberOfEntries=${entries.length}');
  buf.writeln('Version=2');

  return buf.toString();
}

String _flatten(String s) => s.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();
