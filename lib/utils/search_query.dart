/// SearchQuery — split search text into a place and keywords.
///
// Time-stamp: <Thursday 2026-10-15 06:00:00 +1100 Graham Williams>
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

/// Search text taken apart: an optional [place] and the remaining
/// [keywords], either of which may be empty.

typedef SearchQuery = ({String? place, String keywords});

/// The first `@word` or `@"several words"`, anywhere in the text.

final _placePattern = RegExp(r'@(?:"([^"]*)"?|(\S*))');

/// Split [text] into a place, marked with `@`, and the keywords around it.
///
/// 20261015 gjw `@sydney news` searches for "news" within Sydney. A place
/// with a space needs quotes, `@"new york" jazz`, since otherwise there is
/// no telling where the place ends and the keywords begin. Only the first
/// `@` marks a place; a bare `@` marks nothing and is dropped.

SearchQuery parseSearchQuery(String text) {
  final match = _placePattern.firstMatch(text);
  if (match == null) return (place: null, keywords: _squash(text));

  final place = _squash(match.group(1) ?? match.group(2) ?? '');
  final rest = text.replaceRange(match.start, match.end, ' ');

  return (place: place.isEmpty ? null : place, keywords: _squash(rest));
}

/// True when every word of [keywords] appears in [name] or one of [tags],
/// ignoring case. Empty keywords match everything.

bool matchesKeywords(String keywords, String name, List<String> tags) {
  final haystack = [name, ...tags].join(' ').toLowerCase();

  return keywords
      .toLowerCase()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .every(haystack.contains);
}

String _squash(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
