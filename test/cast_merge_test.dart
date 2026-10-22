/// Tests for keeping the listener's place as feeds and devices change.
///
// Time-stamp: <Friday 2026-10-16 06:00:00 +1100 Graham Williams>
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

import 'package:radiopod/models/cast.dart';
import 'package:radiopod/utils/cast_merge.dart';

Cast _cast(
  String guid,
  int day, {
  bool played = false,
  bool disabled = false,
  int position = 0,
  DateTime? updatedAt,
  String title = '',
}) => Cast(
  guid: guid,
  title: title.isEmpty ? guid : title,
  published: DateTime.utc(2026, 10, day),
  audioUrl: 'https://x.example/$guid.mp3',
  played: played,
  disabled: disabled,
  position: Duration(seconds: position),
  updatedAt: updatedAt,
);

final _t1 = DateTime.utc(2026, 10, 16, 8);
final _t2 = DateTime.utc(2026, 10, 16, 9);

void main() {
  group('mergeFeed', () {
    test('a refresh keeps what the listener has done', () {
      final stored = [
        _cast('a', 1, played: true, updatedAt: _t1),
        _cast('b', 2, position: 600, updatedAt: _t1),
      ];
      final fetched = [
        _cast('c', 3),
        _cast('b', 2, title: 'B, retitled'),
        _cast('a', 1),
      ];

      final merged = mergeFeed(stored, fetched);

      expect(merged.map((c) => c.guid), ['c', 'b', 'a']);
      expect(merged[1].title, 'B, retitled');
      expect(merged[1].position, const Duration(seconds: 600));
      expect(merged[2].played, isTrue);
    });

    test('a cast the feed dropped stays only if it was touched', () {
      final stored = [
        _cast('gone-untouched', 1),
        _cast('gone-half-heard', 2, position: 300, updatedAt: _t1),
      ];

      final merged = mergeFeed(stored, [_cast('new', 3)]);

      expect(merged.map((c) => c.guid), ['new', 'gone-half-heard']);
    });

    test('a duplicated guid in the feed is kept once', () {
      final merged = mergeFeed(const [], [_cast('a', 2), _cast('a', 1)]);

      expect(merged, hasLength(1));
    });

    test('keeps no more than the cap', () {
      final fetched = [for (var i = 0; i < 400; i++) _cast('c$i', 1)];

      expect(mergeFeed(const [], fetched), hasLength(maxCastsPerPodcast));
    });
  });

  group('mergeState', () {
    test('the more recently changed copy of each cast wins', () {
      final pod = [_cast('a', 1, position: 100, updatedAt: _t1)];
      final car = [_cast('a', 1, position: 900, updatedAt: _t2)];

      expect(mergeState(pod, car).single.position.inSeconds, 900);
      expect(mergeState(car, pod).single.position.inSeconds, 900);
    });

    test('a cast in only one copy is kept', () {
      final merged = mergeState([_cast('a', 1)], [_cast('b', 2)]);

      expect(merged.map((c) => c.guid), ['b', 'a']);
    });

    test('an untouched copy never overrides a touched one', () {
      final merged = mergeState(
        [_cast('a', 1, played: true, updatedAt: _t1)],
        [_cast('a', 1)],
      );

      expect(merged.single.played, isTrue);
    });

    test('mergeCastMaps covers podcasts in either map', () {
      final merged = mergeCastMaps(
        {
          'p1': [_cast('a', 1)],
        },
        {
          'p2': [_cast('b', 1)],
        },
      );

      expect(merged.keys, unorderedEquals(['p1', 'p2']));
    });
  });

  group('nextCast', () {
    final casts = [
      _cast('newest', 5),
      _cast('played', 4, played: true),
      _cast('middle', 3),
      _cast('disabled', 2, disabled: true),
      _cast('oldest', 1),
    ];

    test('a tap plays the newest available', () {
      expect(nextCast(casts)?.guid, 'newest');
    });

    test('then works backwards, skipping played and disabled', () {
      expect(nextCast(casts, after: 'newest')?.guid, 'middle');
      expect(nextCast(casts, after: 'middle')?.guid, 'oldest');
      expect(nextCast(casts, after: 'oldest'), isNull);
    });

    test('an unknown cast has nothing after it', () {
      expect(nextCast(casts, after: 'nope'), isNull);
    });

    test('a tap resumes the part-heard cast, not the newest', () {
      final withPartial = [
        _cast('newest', 5),
        _cast('half', 3, position: 900, updatedAt: DateTime.utc(2026, 10, 6)),
        _cast('oldest', 1),
      ];

      expect(castToStart(withPartial)?.guid, 'half');
      expect(castToStart(casts)?.guid, 'newest');
    });

    test('of several part heard, the one heard most recently', () {
      final two = [
        _cast('a', 5, position: 60, updatedAt: DateTime.utc(2026, 10, 6)),
        _cast('b', 3, position: 60, updatedAt: DateTime.utc(2026, 10, 7)),
      ];

      expect(castToStart(two)?.guid, 'b');
    });

    test('a part-heard cast switched off is passed over', () {
      final off = [
        _cast('newest', 5),
        _cast('half', 3, position: 900, disabled: true),
      ];

      expect(castToStart(off)?.guid, 'newest');
    });

    test('nothing left to play is null, and counts zero', () {
      final heard = [_cast('a', 1, played: true)];

      expect(nextCast(heard), isNull);
      expect(availableCount(heard), 0);
      expect(availableCount(casts), 3);
    });
  });

  group('isFinished', () {
    const hour = Duration(hours: 1);

    test('within the last 30 seconds of a long cast', () {
      expect(isFinished(hour - const Duration(seconds: 29), hour), isTrue);
      expect(isFinished(hour - const Duration(seconds: 31), hour), isFalse);
    });

    test('a short cast needs its last tenth, not its last 30 s', () {
      const trailer = Duration(seconds: 40);

      expect(isFinished(const Duration(seconds: 5), trailer), isFalse);
      expect(isFinished(const Duration(seconds: 37), trailer), isTrue);
    });

    test('an unknown length is never finished by position', () {
      expect(isFinished(hour, null), isFalse);
    });
  });
}
