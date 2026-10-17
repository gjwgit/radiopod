/// Tests for the cast model and for keeping casts on the device.
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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/models/cast.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/cast_store.dart';
import 'package:radiopod/services/pod_service.dart';

import 'support/debug_print_capture.dart';

final _cast = Cast(
  guid: 'g1',
  title: 'Episode "one" \\ with a backslash',
  published: DateTime.utc(2026, 10, 16, 4),
  audioUrl: 'https://x.example/1.mp3?a=1&b=2',
  duration: const Duration(minutes: 30),
  description: 'Café, «quotes», """triple""" and a\nnewline',
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    CastStore.resetForTest();
  });

  group('Cast', () {
    test('round-trips through JSON, awkward text included', () {
      final c = _cast.withState(
        position: const Duration(seconds: 754),
        at: DateTime.utc(2026, 10, 16, 9),
      );
      final back = Cast.fromJson(c.toJson());

      expect(back.title, c.title);
      expect(back.description, c.description);
      expect(back.audioUrl, c.audioUrl);
      expect(back.published, c.published);
      expect(back.duration, c.duration);
      expect(back.position, const Duration(seconds: 754));
      expect(back.updatedAt, DateTime.utc(2026, 10, 16, 9));
    });

    test('a fresh cast writes no state at all', () {
      final json = _cast.toJson();

      expect(json.keys, isNot(contains('played')));
      expect(json.keys, isNot(contains('disabled')));
      expect(json.keys, isNot(contains('position')));
      expect(json.keys, isNot(contains('updatedAt')));
    });

    test('available and remaining', () {
      expect(_cast.available, isTrue);
      expect(_cast.withState(played: true).available, isFalse);
      expect(_cast.withState(disabled: true).available, isFalse);
      expect(
        _cast.withState(position: const Duration(minutes: 10)).remaining,
        const Duration(minutes: 20),
      );
    });

    test('withFeedOf takes the feed and keeps the state', () {
      final heard = _cast.withState(played: true, at: DateTime.utc(2026));
      final fresh = Cast(
        guid: 'g1',
        title: 'Retitled',
        published: _cast.published,
        audioUrl: 'https://x.example/moved.mp3',
      );
      final merged = heard.withFeedOf(fresh);

      expect(merged.title, 'Retitled');
      expect(merged.audioUrl, 'https://x.example/moved.mp3');
      expect(merged.played, isTrue);
      expect(merged.duration, _cast.duration);
    });
  });

  group('Station as a podcast', () {
    test('isPodcast and author round-trip, and are absent for radio', () {
      const podcast = Station(
        id: 'p1',
        name: 'Future Tense',
        url: 'https://x.example/feed.xml',
        isPodcast: true,
        author: 'ABC Australia',
      );
      final back = Station.fromJson(podcast.toJson());

      expect(back.isPodcast, isTrue);
      expect(back.author, 'ABC Australia');
      expect(back.subtitle, 'Podcast · ABC Australia');

      const radio = Station(id: 's1', name: 'R', url: 'https://x.example/r');
      expect(radio.toJson().keys, isNot(contains('isPodcast')));
      expect(Station.fromJson(radio.toJson()).isPodcast, isFalse);
    });
  });

  group('encodeCasts / decodeCasts', () {
    test('round-trip a map of podcasts', () {
      final back = decodeCasts(
        encodeCasts({
          'p1': [_cast],
          'p2': const [],
        }),
      );

      expect(back.keys, unorderedEquals(['p1', 'p2']));
      expect(back['p1']!.single.description, _cast.description);
    });

    test('one unreadable podcast does not cost the others', () async {
      late final Map<String, List<Cast>> back;
      final log = await captureDebugPrint(() async {
        back = decodeCasts('{"good":[], "bad":[{"title":"no guid"}]}');
      });

      expect(back.keys, ['good']);
      expect(log.single, contains('discarding casts of bad'));
    });

    test('survive the Pod file\'s Turtle wrapper intact', () {
      // casts.ttl holds JSON inside a """…""" literal. Show notes are full
      // of quotes; JSON escapes each one, so three in a row never reach the
      // file and the literal cannot be closed early.

      final json = encodeCasts({
        'p1': [_cast],
      });
      final ttl = PodService.buildTtl('casts.ttl', json);

      expect(PodService.extractJson(ttl), json);
      expect(
        decodeCasts(PodService.extractJson(ttl))['p1']!.single.title,
        _cast.title,
      );
    });

    test('rubbish is an empty map', () async {
      await captureDebugPrint(() async {
        expect(decodeCasts('not json'), isEmpty);
      });
      expect(decodeCasts(null), isEmpty);
      expect(decodeCasts('[]'), isEmpty);
    });
  });

  group('CastStore', () {
    test('survives a restart through the device copy', () async {
      await CastStore.put('p1', [_cast]);
      CastStore.resetForTest();
      expect(CastStore.of('p1'), isEmpty);

      await CastStore.load();
      expect(CastStore.of('p1').single.guid, 'g1');
    });

    test('update changes one cast and announces the podcast', () async {
      await CastStore.put('p1', [_cast]);
      final announced = CastStore.changes.first;

      await CastStore.update(
        'p1',
        'g1',
        (c) => c.withState(position: const Duration(minutes: 5)),
      );

      expect(await announced, 'p1');
      expect(CastStore.of('p1').single.position, const Duration(minutes: 5));
    });

    test('update of an unknown cast does nothing', () async {
      await CastStore.update('p1', 'nope', (c) => c.withState(played: true));

      expect(CastStore.of('p1'), isEmpty);
    });

    test('retainOnly drops podcasts no longer in the library', () async {
      await CastStore.put('keep', [_cast]);
      await CastStore.put('drop', [_cast]);
      await CastStore.retainOnly({'keep'});

      expect(CastStore.all.keys, ['keep']);
    });

    test('replaceAll, the Pod load, announces no unsaved change', () async {
      final announced = <String>[];
      final sub = CastStore.changes.listen(announced.add);
      await CastStore.replaceAll({
        'p1': [_cast],
      });
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(announced, isEmpty);
      expect(CastStore.of('p1').single.guid, _cast.guid);
    });
  });

  group('setAllCastsDisabled', () {
    test(
      'skips every cast, and unskips them, keeping what was heard',
      () async {
        final heard = _cast.withState(played: true, at: DateTime.utc(2026));
        final other = Cast(
          guid: 'g2',
          title: 'Two',
          published: DateTime.utc(2026, 10, 15),
          audioUrl: 'https://x.example/2.mp3',
        );
        await CastStore.put('p1', [heard, other]);
        final provider = AppProvider()..loadForTest(const [], const []);

        await provider.setAllCastsDisabled('p1', true);
        expect(CastStore.of('p1').every((c) => c.disabled), isTrue);
        expect(provider.castsToPlay('p1'), 0);

        await provider.setAllCastsDisabled('p1', false);
        expect(CastStore.of('p1').any((c) => c.disabled), isFalse);
        expect(CastStore.of('p1').first.played, isTrue);
        expect(provider.castsToPlay('p1'), 1);
      },
    );
  });
}
