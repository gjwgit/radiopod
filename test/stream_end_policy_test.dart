/// Tests for what happens when a stream ends.
///
/// The two cases have names here because they are real stations that behave
/// in opposite ways, and getting one right by breaking the other is the
/// whole difficulty: NPR's bulletin FINISHES and replays if reconnected,
/// while ABC News Radio's connection merely DROPS and is still on air.
///
// Time-stamp: <Tuesday 2026-09-22 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/stream_end_policy.dart';

/// A station that clearly played before it ended.

const _listened = Duration(minutes: 5);

/// A stream that ended almost at once — dead, refused, or the wrong codec.

const _instant = Duration(milliseconds: 300);

void main() {
  group('a programme that finishes (NPR, the default)', () {
    test('moves on to the next station', () {
      final d = decideStreamEnd(
        queueLength: 3,
        failedAdvances: 0,
        played: _listened,
        reconnectOnEnd: false,
      );

      expect(d.action, StreamEndAction.advance);
    });

    test('is never reconnected, however long it played', () {
      // Reconnecting replays the same news, which is the bug this flag
      // exists to prevent.

      final d = decideStreamEnd(
        queueLength: 5,
        failedAdvances: 0,
        played: const Duration(hours: 2),
        reconnectOnEnd: false,
      );

      expect(d.action, isNot(StreamEndAction.reconnect));
    });

    test('a long healthy run does not count against the queue', () {
      // The tally is about stations that would not play. A station that ran
      // for five minutes and finished is not one of them.

      final d = decideStreamEnd(
        queueLength: 3,
        failedAdvances: 2,
        played: _listened,
        reconnectOnEnd: false,
      );

      expect(d.action, StreamEndAction.advance);
      expect(d.failedAdvances, 1);
    });

    test('stops when it is the only station in the queue', () {
      final d = decideStreamEnd(
        queueLength: 1,
        failedAdvances: 0,
        played: _listened,
        reconnectOnEnd: false,
      );

      expect(d.action, StreamEndAction.stop);
    });
  });

  group('a continuous station (ABC News Radio, flag on)', () {
    test('is reconnected rather than abandoned', () {
      final d = decideStreamEnd(
        queueLength: 3,
        failedAdvances: 0,
        played: _listened,
        reconnectOnEnd: true,
      );

      expect(d.action, StreamEndAction.reconnect);
    });

    test('is reconnected even as the only station in the queue', () {
      final d = decideStreamEnd(
        queueLength: 1,
        failedAdvances: 0,
        played: _listened,
        reconnectOnEnd: true,
      );

      expect(d.action, StreamEndAction.reconnect);
    });

    test('playing for exactly the threshold counts', () {
      final d = decideStreamEnd(
        queueLength: 2,
        failedAdvances: 0,
        played: realListenTime,
        reconnectOnEnd: true,
      );

      expect(d.action, StreamEndAction.reconnect);
    });

    test('a stale URL is not retried for ever', () {
      // Marked continuous, but the stream no longer opens. Without the
      // playing-time condition this would reconnect endlessly.

      final d = decideStreamEnd(
        queueLength: 3,
        failedAdvances: 0,
        played: _instant,
        reconnectOnEnd: true,
      );

      expect(d.action, StreamEndAction.advance);
      expect(d.failedAdvances, 1);
    });

    test('a reconnect that dies at once gives up after one try', () {
      // The handler resets the clock before reconnecting, so a second
      // ending arrives with almost no playing time and the queue moves on.

      final first = decideStreamEnd(
        queueLength: 3,
        failedAdvances: 0,
        played: _listened,
        reconnectOnEnd: true,
      );
      expect(first.action, StreamEndAction.reconnect);

      final second = decideStreamEnd(
        queueLength: 3,
        failedAdvances: first.failedAdvances,
        played: _instant,
        reconnectOnEnd: true,
      );
      expect(second.action, StreamEndAction.advance);
    });

    test('a long session of drops never creeps towards a stop', () {
      var tally = 0;
      for (var i = 0; i < 100; i++) {
        final d = decideStreamEnd(
          queueLength: 3,
          failedAdvances: tally,
          played: _listened,
          reconnectOnEnd: true,
        );
        tally = d.failedAdvances;
        expect(d.action, StreamEndAction.reconnect, reason: 'at $i');
        expect(tally, 0);
      }
    });
  });

  group('the loop guard', () {
    test('a whole queue of dead stations terminates', () {
      const queueLength = 4;
      var tally = 0;
      var advances = 0;

      while (true) {
        final d = decideStreamEnd(
          queueLength: queueLength,
          failedAdvances: tally,
          played: _instant,
          reconnectOnEnd: false,
        );
        tally = d.failedAdvances;
        if (d.action != StreamEndAction.advance) break;
        advances++;
        expect(advances, lessThan(50), reason: 'auto-advance did not stop');
      }

      expect(advances, queueLength);
    });

    test('the grace period is not mistaken for playing time', () {
      // The handler measures playing time when the stream ENDED, before any
      // waiting. If it ever included resumeGrace, a stream that died at once
      // could be scored as a real listen and reset the tally.

      expect(resumeGrace, lessThan(realListenTime));

      final d = decideStreamEnd(
        queueLength: 3,
        failedAdvances: 0,
        played: resumeGrace + const Duration(milliseconds: 500),
        reconnectOnEnd: false,
      );

      expect(d.action, StreamEndAction.advance);
    });
  });

  group('the station flag', () {
    test('defaults to moving on', () {
      const s = Station(id: 's', name: 'n', url: 'https://live.example/n');

      expect(s.reconnectOnEnd, isFalse);
    });

    test('round-trips through JSON when set', () {
      const s = Station(
        id: 's',
        name: 'ABC News Radio',
        url: 'https://live.example/abc',
        reconnectOnEnd: true,
      );

      expect(Station.fromJson(s.toJson()).reconnectOnEnd, isTrue);
    });

    test('is left out of JSON when off, keeping stored data small', () {
      const s = Station(id: 's', name: 'n', url: 'https://live.example/n');

      expect(s.toJson().containsKey('reconnectOnEnd'), isFalse);
      expect(Station.fromJson(s.toJson()).reconnectOnEnd, isFalse);
    });

    test('a station saved before the flag existed reads as off', () {
      final s = Station.fromJson({
        'id': 's',
        'name': 'Old',
        'url': 'https://live.example/o',
      });

      expect(s.reconnectOnEnd, isFalse);
    });

    test('an HLS stream is marked in the subtitle', () {
      // Visible in Search and in the Stations list, so the entry that dies
      // after a minute on the desktop can be recognised and avoided.

      const s = Station(
        id: 's',
        name: 'ABC News Radio',
        url: 'https://live.example/v0-221.m3u8',
        codec: 'AAC+',
        isHls: true,
      );

      expect(s.subtitle, 'AAC+ · HLS');
    });

    test('a continuous stream carries no HLS marker', () {
      const s = Station(
        id: 's',
        name: 'ABC News Radio',
        url: 'https://live.example/icecast.audio',
        codec: 'AAC+',
      );

      expect(s.subtitle, 'AAC+');
      expect(s.isHls, isFalse);
    });

    test('isHls round-trips and defaults off for older data', () {
      const s = Station(
        id: 's',
        name: 'n',
        url: 'https://live.example/n',
        isHls: true,
      );

      expect(Station.fromJson(s.toJson()).isHls, isTrue);
      expect(
        Station.fromJson({
          'id': 's',
          'name': 'Old',
          'url': 'https://live.example/o',
        }).isHls,
        isFalse,
      );
    });

    test('copyWith can turn it on and off again', () {
      const s = Station(id: 's', name: 'n', url: 'https://live.example/n');

      expect(s.copyWith(reconnectOnEnd: true).reconnectOnEnd, isTrue);
      expect(
        s
            .copyWith(reconnectOnEnd: true)
            .copyWith(reconnectOnEnd: false)
            .reconnectOnEnd,
        isFalse,
      );
    });
  });
}
