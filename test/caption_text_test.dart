/// Tests for turning recogniser output into readable caption text.
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

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/services/captions/caption_text.dart';

void main() {
  group('tidyCaption', () {
    test('turns shouting into sentence case', () {
      expect(
        tidyCaption('TOKYO HAS RECORDED THIRTY FOUR DAYS OF RAIN'),
        'Tokyo has recorded thirty four days of rain',
      );
    });

    test('restores the pronoun I and its contractions', () {
      expect(
        tidyCaption("I THINK I'M RIGHT AND I'LL SAY SO"),
        "I think I'm right and I'll say so",
      );
    });

    test('does not capitalise words that merely begin with i', () {
      expect(tidyCaption('IN IRELAND IT IS'), 'In ireland it is');
    });

    test('collapses stray whitespace and handles nothing heard', () {
      expect(tidyCaption('  HELLO   THERE '), 'Hello there');
      expect(tidyCaption(''), '');
      expect(tidyCaption('   '), '');
    });
  });

  group('captionTail', () {
    test('leaves a short line alone', () {
      expect(captionTail('Good morning'), 'Good morning');
    });

    test('keeps the end of a long line, cut on a word boundary', () {
      final tail = captionTail(
        'A decommissioned american warship has been deliberately sunk as '
        'part of a training exercise',
        max: 30,
      );

      expect(tail, '…as part of a training exercise');
      expect(tail.length, lessThanOrEqualTo(31));
    });

    test('cuts mid-word only when there is no space to cut at', () {
      expect(captionTail('abcdefghijklmnop', max: 5), '…lmnop');
    });

    test('counts a Chinese character as two columns', () {
      const text = '包括尤其是我们叫大熊猫它因为要吃竹子嘛';

      expect(captionTail(text, max: 10), '…要吃竹子嘛');
      expect(captionTail(text, max: 40), text);
    });

    test('does not skip Chinese to reach a space', () {
      expect(captionTail('前面的话 我们说的是 AL', max: 12), '…们说的是 AL');
    });
  });

  group('joinCaptions', () {
    test('puts a space between English', () {
      expect(joinCaptions('and then', 'it rained'), 'and then it rained');
    });

    test('puts no space into Chinese', () {
      expect(joinCaptions('我们饲养员', '呢'), '我们饲养员呢');
    });

    test('either side may be empty', () {
      expect(joinCaptions('', '呢'), '呢');
      expect(joinCaptions('done', ''), 'done');
    });
  });
}
