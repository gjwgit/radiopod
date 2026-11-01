/// Tests for splitting search text into a place and keywords.
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

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/utils/search_query.dart';

void main() {
  group('parseSearchQuery', () {
    test('@place then keywords', () {
      expect(parseSearchQuery('@sydney news'), (
        place: 'sydney',
        keywords: 'news',
      ));
    });

    test('the place can come anywhere', () {
      expect(parseSearchQuery('classic  @melbourne fm'), (
        place: 'melbourne',
        keywords: 'classic fm',
      ));
    });

    test('quotes hold a place of several words', () {
      expect(parseSearchQuery('@"new york" jazz'), (
        place: 'new york',
        keywords: 'jazz',
      ));
    });

    test('an unclosed quote takes the rest as the place', () {
      expect(parseSearchQuery('@"new york'), (place: 'new york', keywords: ''));
    });

    test('no @ is all keywords', () {
      expect(parseSearchQuery('  ABC   Classic '), (
        place: null,
        keywords: 'ABC Classic',
      ));
    });

    test('a bare @ marks nothing and is dropped', () {
      expect(parseSearchQuery('jazz @'), (place: null, keywords: 'jazz'));
      expect(parseSearchQuery('@"" jazz'), (place: null, keywords: 'jazz'));
    });

    test('only the first @ is a place', () {
      expect(parseSearchQuery('@sydney @news'), (
        place: 'sydney',
        keywords: '@news',
      ));
    });
  });

  group('matchesKeywords', () {
    test('every word must appear in the name or a genre', () {
      expect(matchesKeywords('jazz fm', 'Smooth FM', ['jazz']), isTrue);
      expect(matchesKeywords('jazz fm', 'Smooth FM', ['soul']), isFalse);
    });

    test('ignores case', () {
      expect(matchesKeywords('NEWS', 'ABC News Radio', []), isTrue);
    });

    test('no keywords match everything', () {
      expect(matchesKeywords('', 'Anything', []), isTrue);
    });
  });
}
