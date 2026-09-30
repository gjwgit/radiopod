/// Caption text — turning recogniser output into something readable.
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
/// Authors: Tony Chen

library;

/// Recogniser output as a sentence.
///
/// The English models emit bare upper case with no punctuation, which reads
/// as shouting. Sentence case, with the pronoun "I" restored, is far easier
/// to follow at a glance. Punctuation is not guessed at: a wrong full stop
/// misleads more than a missing one.

String tidyCaption(String raw) {
  final words = raw.trim().toLowerCase().split(RegExp(r'\s+'));
  if (words.length == 1 && words.first.isEmpty) return '';

  final fixed = [
    for (final w in words)
      if (w == 'i' || w.startsWith("i'")) 'I${w.substring(1)}' else w,
  ].join(' ');

  return fixed[0].toUpperCase() + fixed.substring(1);
}

/// The end of [text], cut to at most [max] columns on a word boundary.
///
/// For the lock screen, where the title is one or two lines wide and the
/// words just spoken are the ones worth showing — the way a lyrics display
/// keeps the current line rather than the verse.
///
/// Measured in COLUMNS, not characters: a Chinese character is about as wide
/// as two Latin letters, so it counts as two. Chinese is written without
/// spaces, so there the cut simply falls between characters.

String captionTail(String text, {int max = 60}) {
  final t = text.trim();
  final runes = t.runes.toList();

  var width = 0;
  var start = runes.length;
  while (start > 0) {
    final w = _isWide(runes[start - 1]) ? 2 : 1;
    if (width + w > max) break;
    width += w;
    start--;
  }
  if (start == 0) return t;

  // Only a cut through the middle of a Latin word moves on to the next
  // space. Between Chinese characters every position is a boundary, and
  // skipping ahead there would throw away words for nothing.

  var from = start;
  final midWord = _isLetter(runes[start - 1]) && _isLetter(runes[start]);
  if (midWord) {
    final space = runes.indexOf(0x20, start);
    if (space > 0 && space < runes.length - 1) from = space + 1;
  }

  return '…${String.fromCharCodes(runes.sublist(from)).trimLeft()}';
}

bool _isLetter(int rune) => !_isWide(rune) && rune != 0x20;

/// [before] and [after] run together as one line of speech.
///
/// A space between them in English; none in Chinese, which is written
/// without, so a line that settled mid-sentence does not leave a gap.

String joinCaptions(String before, String after) {
  if (before.isEmpty) return after;
  if (after.isEmpty) return before;

  final wide = _isWide(before.runes.last) || _isWide(after.runes.first);

  return wide ? '$before$after' : '$before $after';
}

/// CJK ideographs, kana, Hangul and full-width forms: the characters a
/// lock screen draws at double width.

bool _isWide(int rune) =>
    (rune >= 0x1100 && rune <= 0x115F) ||
    (rune >= 0x2E80 && rune <= 0xA4CF) ||
    (rune >= 0xAC00 && rune <= 0xD7A3) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0xFE30 && rune <= 0xFE4F) ||
    (rune >= 0xFF00 && rune <= 0xFF60) ||
    (rune >= 0xFFE0 && rune <= 0xFFE6) ||
    (rune >= 0x20000 && rune <= 0x3FFFD);
