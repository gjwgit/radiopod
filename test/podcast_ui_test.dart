/// Tests for how podcasts and their casts are shown and described.
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

import 'package:flutter/material.dart';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/cast.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/podcast_widgets/cast_tile.dart';
import 'package:radiopod/services/browse_tree.dart';
import 'package:radiopod/services/cast_playback.dart';
import 'package:radiopod/utils/cast_text.dart';
import 'package:radiopod/widgets/cast_controls.dart';
import 'package:radiopod/widgets/station_tile.dart';

const _podcast = Station(
  id: 'p1',
  name: 'Future Tense',
  url: 'https://x.example/feed.xml',
  isPodcast: true,
  author: 'ABC Australia',
);

final _cast = Cast(
  guid: 'g1',
  title: 'The danger of generational labelling',
  published: DateTime.utc(2026, 1, 15, 22, 30),
  audioUrl: 'https://x.example/1.mp3',
  duration: const Duration(minutes: 29, seconds: 6),
  description: 'Terms like Gen Z and Boomer have no basis in science.',
);

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byType(Opacity).first).opacity;

void main() {
  group('podcast rows', () {
    test('the app says how many casts are left to hear', () {
      expect(
        podcastDetails(_podcast, toPlay: 5, total: 120),
        'Podcast · ABC Australia · 5 to play of 120',
      );
      expect(
        podcastDetails(_podcast, toPlay: 0, total: 3),
        'Podcast · ABC Australia · all 3 heard',
      );
      expect(
        podcastDetails(_podcast, toPlay: 0, total: 0),
        'Podcast · ABC Australia · no episodes yet',
      );
    });

    test('the car gets a shorter line, and the row is not live', () {
      final item = stationMediaItem(
        _podcast,
        browseAllStationsId,
        details: podcastCarDetails(5),
      );

      expect(item.artist, 'Podcast · 5 to play');
      expect(item.isLive, isFalse);
      expect(podcastCarDetails(0), 'Podcast · all heard');
    });

    test('browseChildren asks for podcast details row by row', () {
      const radio = Station(id: 's1', name: 'R', url: 'https://x.example/r');
      final items = browseChildren(
        browseAllStationsId,
        const [radio, _podcast],
        const [],
        detailsOf: (s) => s.isPodcast ? 'Podcast · 2 to play' : null,
      );

      expect(items.first.isLive, isTrue);
      expect(items.last.artist, 'Podcast · 2 to play');
    });

    testWidgets('a podcast falls back to the podcasts glyph', (tester) async {
      await _pump(tester, const StationTile(station: _podcast));

      expect(find.byIcon(Icons.podcasts), findsOneWidget);
    });
  });

  group('cast text', () {
    test('lengths', () {
      expect(castLength(const Duration(seconds: 45)), '45 s');
      expect(castLength(const Duration(minutes: 29, seconds: 6)), '29 min');
      expect(castLength(const Duration(minutes: 64)), '1 h 4 min');
      expect(castLength(const Duration(hours: 2)), '2 h');
    });

    test('summary says how far the listener got', () {
      final half = _cast.withState(position: const Duration(minutes: 9));

      expect(castSummary(half), endsWith('29 min · 20 min left'));
      expect(castSummary(_cast.withState(played: true)), endsWith('Played'));
      expect(castSummary(_cast.withState(disabled: true)), endsWith('Skipped'));
    });

    test('clock time', () {
      expect(clockTime(const Duration(minutes: 4, seconds: 5)), '4:05');
      expect(
        clockTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });

  group('cast session', () {
    test('the cast item keeps the podcast id so rows still find it', () {
      final base = stationMediaItem(_podcast, browseAllStationsId);
      final item = castSessionItem(base, _podcast, _cast);

      expect(item.id, base.id);
      expect(item.extras!['stationId'], 'p1');
      expect(item.extras!['castGuid'], 'g1');
      expect(item.extras!['track'], _cast.title);
      expect(item.title, _cast.title);
      expect(item.artist, 'Future Tense');
      expect(item.duration, _cast.duration);
      expect(item.isLive, isFalse);
    });

    test('controls: pause not stop, skips only where there is a cast', () {
      final first = castControls(
        playing: true,
        hasOlder: true,
        hasNewer: false,
      );

      expect(first.controls, [
        MediaControl.rewind,
        MediaControl.pause,
        MediaControl.fastForward,
        MediaControl.skipToNext,
      ]);
      expect(first.compact, [0, 1, 2]);

      final middle = castControls(
        playing: false,
        hasOlder: true,
        hasNewer: true,
      );
      expect(middle.controls.first, MediaControl.skipToPrevious);
      expect(middle.controls, contains(MediaControl.play));
      // The compact view is always back, play/pause, forward.
      expect(middle.compact.map((i) => middle.controls[i]), [
        MediaControl.rewind,
        MediaControl.play,
        MediaControl.fastForward,
      ]);
    });

    test('a resumed cast starts five seconds back, never before 0:00', () {
      expect(
        resumeFrom(const Duration(minutes: 12, seconds: 30)),
        const Duration(minutes: 12, seconds: 25),
      );
      expect(resumeFrom(const Duration(seconds: 3)), Duration.zero);
      expect(resumeFrom(Duration.zero), Duration.zero);
    });

    test('a seek is kept within the cast', () {
      const length = Duration(minutes: 30);

      expect(clampSeek(const Duration(seconds: -5), length), Duration.zero);
      expect(
        clampSeek(const Duration(minutes: 31), length),
        length - const Duration(seconds: 1),
      );
      expect(
        clampSeek(const Duration(minutes: 31), null),
        const Duration(minutes: 31),
      );
    });
  });

  group('CastTile', () {
    Widget tile(Cast c, {bool current = false}) => CastTile(
      cast: c,
      current: current,
      onTap: () {},
      onEnabled: (_) {},
      onPlayed: (_) {},
    );

    testWidgets('a cast still to hear is drawn in full', (tester) async {
      await _pump(tester, tile(_cast));

      expect(_opacity(tester), 1);
      expect(find.text(_cast.title), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('a played cast stays listed, greyed', (tester) async {
      await _pump(tester, tile(_cast.withState(played: true)));

      expect(find.text(_cast.title), findsOneWidget);
      expect(_opacity(tester), lessThan(1));
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('a switched-off cast is greyed with its switch off', (
      tester,
    ) async {
      await _pump(tester, tile(_cast.withState(disabled: true)));

      expect(_opacity(tester), lessThan(1));
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('the cast on air is never greyed', (tester) async {
      await _pump(tester, tile(_cast.withState(played: true), current: true));

      expect(_opacity(tester), 1);
    });

    testWidgets('the switch reports the new setting', (tester) async {
      bool? enabled;
      await _pump(
        tester,
        CastTile(
          cast: _cast,
          onTap: () {},
          onEnabled: (on) => enabled = on,
          onPlayed: (_) {},
        ),
      );
      await tester.tap(find.byType(Switch));

      expect(enabled, isFalse);
    });
  });
}
