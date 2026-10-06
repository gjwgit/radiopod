/// Tests for the sleep timer and its wording.
///
// Time-stamp: <Tuesday 2026-10-06 19:00:00 +1100 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
//
/// Authors: Graham Williams

library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/services/sleep_preference.dart';
import 'package:radiopod/services/sleep_timer.dart';
import 'package:radiopod/utils/sleep_timer_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SleepPreference', () {
    test('falls back to the default when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await SleepPreference.load(), sleepTimerDefault);
    });

    test('remembers what Settings chose', () async {
      SharedPreferences.setMockInitialValues({});
      await SleepPreference.save(const Duration(minutes: 90));

      expect(await SleepPreference.load(), const Duration(minutes: 90));
    });

    // A value that is no longer offered would leave the Settings dropdown
    // with a value it cannot show, which throws rather than looking odd.

    test('a stored value that is no longer offered falls back', () async {
      SharedPreferences.setMockInitialValues({'sleep_timer_minutes': 7});

      expect(await SleepPreference.load(), sleepTimerDefault);
    });

    test('stored as plain minutes, so the value stays readable', () async {
      SharedPreferences.setMockInitialValues({});
      await SleepPreference.save(const Duration(minutes: 45));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('sleep_timer_minutes'), 45);
    });
  });

  group('SleepTimer', () {
    tearDown(() => SleepTimer.nowForTest = DateTime.now);

    /// Run [body] with both the clock and the timer under test control.
    ///
    /// SleepTimer reads the wall clock to work out what is left, and uses a
    /// periodic Timer to notice. fake_async moves the Timer; nowForTest has
    /// to move with it or the two disagree and nothing ever expires.

    void withFakeClock(
      void Function(FakeAsync async, SleepTimer t, List<int> fired) body,
    ) {
      fakeAsync((async) {
        final start = DateTime(2026, 10, 6, 22);
        SleepTimer.nowForTest = () => start.add(async.elapsed);

        final fired = <int>[];
        final timer = SleepTimer(() async => fired.add(1));
        addTearDown(timer.dispose);

        body(async, timer, fired);
      });
    }

    test('stops playback when the time is up', () {
      withFakeClock((async, timer, fired) {
        timer.start(const Duration(minutes: 30));

        async.elapse(const Duration(minutes: 29));
        expect(fired, isEmpty, reason: 'not yet');

        async.elapse(const Duration(minutes: 1));
        expect(fired, hasLength(1));
      });
    });

    test('stops playback exactly once, not every second after', () {
      withFakeClock((async, timer, fired) {
        timer.start(const Duration(minutes: 1));
        async.elapse(const Duration(minutes: 10));

        expect(fired, hasLength(1));
        expect(timer.isRunning, isFalse);
      });
    });

    test('a cancelled timer never fires', () {
      withFakeClock((async, timer, fired) {
        timer.start(const Duration(minutes: 30));
        async.elapse(const Duration(minutes: 10));
        timer.cancel();

        async.elapse(const Duration(hours: 2));
        expect(fired, isEmpty);
        expect(timer.isRunning, isFalse);
      });
    });

    test('setting a new time replaces the old one', () {
      withFakeClock((async, timer, fired) {
        timer.start(const Duration(minutes: 15));
        async.elapse(const Duration(minutes: 5));
        timer.start(const Duration(minutes: 60));

        // The first timer would have fired ten minutes from here.

        async.elapse(const Duration(minutes: 30));
        expect(fired, isEmpty, reason: 'the 15 minute timer was replaced');

        async.elapse(const Duration(minutes: 30));
        expect(fired, hasLength(1));
      });
    });

    // A zero or negative duration must CANCEL rather than fire at once.
    // Silencing a station the instant someone set a timer would look like
    // the app had crashed.

    test('a zero duration cancels instead of stopping playback', () {
      withFakeClock((async, timer, fired) {
        timer.start(Duration.zero);
        async.elapse(const Duration(minutes: 5));

        expect(fired, isEmpty);
        expect(timer.isRunning, isFalse);
      });
    });

    test('minutesLeft counts down and rounds up', () {
      withFakeClock((async, timer, fired) {
        expect(timer.minutesLeft.value, isNull, reason: 'nothing set');

        timer.start(const Duration(minutes: 30));
        expect(timer.minutesLeft.value, 30);

        // Half a minute in, 29½ remain, which must still read 30 rather
        // than counting down before a whole minute has passed.

        async.elapse(const Duration(seconds: 30));
        expect(timer.minutesLeft.value, 30);

        async.elapse(const Duration(seconds: 30));
        expect(timer.minutesLeft.value, 29);
      });
    });

    test('minutesLeft goes back to null once it has fired', () {
      withFakeClock((async, timer, fired) {
        timer.start(const Duration(minutes: 1));
        async.elapse(const Duration(minutes: 2));

        expect(timer.minutesLeft.value, isNull);
      });
    });

    // The app bar is a plain switch, so toggle() is what it calls.

    test('toggle turns the timer on for the chosen default', () {
      withFakeClock((async, timer, fired) {
        timer.defaultDuration = const Duration(minutes: 45);

        expect(timer.toggle(), isTrue);
        expect(timer.minutesLeft.value, 45);

        async.elapse(const Duration(minutes: 45));
        expect(fired, hasLength(1));
      });
    });

    test('toggle turns a running timer off, and does not stop playback', () {
      withFakeClock((async, timer, fired) {
        timer.toggle();
        async.elapse(const Duration(minutes: 5));

        expect(timer.toggle(), isFalse);
        expect(timer.isRunning, isFalse);

        async.elapse(const Duration(hours: 2));
        expect(fired, isEmpty, reason: 'turning it off is not a stop');
      });
    });

    test('toggle starts from 30 minutes until Settings says otherwise', () {
      withFakeClock((async, timer, fired) {
        timer.toggle();

        expect(timer.minutesLeft.value, 30);
      });
    });

    // The default has to be one of the offered choices, or Settings would
    // open with a dropdown value it cannot show.

    test('the default is one of the choices offered', () {
      expect(sleepTimerChoices, contains(sleepTimerDefault));
    });

    test('the default is 30 minutes', () {
      expect(sleepTimerDefault, const Duration(minutes: 30));
    });
  });

  group('sleepTimerLabel', () {
    test('minutes under the hour', () {
      expect(sleepTimerLabel(const Duration(minutes: 15)), '15 minutes');
      expect(sleepTimerLabel(const Duration(minutes: 45)), '45 minutes');
    });

    test('a single hour is singular', () {
      expect(sleepTimerLabel(const Duration(minutes: 60)), '1 hour');
    });

    test('ninety minutes reads as an hour and a half', () {
      expect(sleepTimerLabel(const Duration(minutes: 90)), '1½ hours');
    });

    test('two hours is plural', () {
      expect(sleepTimerLabel(const Duration(minutes: 120)), '2 hours');
    });

    test('an odd remainder keeps the hour singular', () {
      // This read "1 hours 15 minutes" first time round. The half-hour case
      // is the one that stays plural, not every remainder.

      expect(sleepTimerLabel(const Duration(minutes: 75)), '1 hour 15 minutes');
      expect(
        sleepTimerLabel(const Duration(minutes: 140)),
        '2 hours 20 minutes',
      );
    });

    test('a single minute is singular', () {
      expect(sleepTimerLabel(const Duration(minutes: 1)), '1 minute');
    });

    test('no offered choice reads ungrammatically', () {
      for (final choice in sleepTimerChoices) {
        expect(sleepTimerLabel(choice), isNot(contains('1 hours ')));
        expect(sleepTimerLabel(choice), isNot(contains(' 1 minutes')));
      }
    });
  });

  group('sleepTimerSummary', () {
    test('no timer set', () {
      expect(sleepTimerSummary(null), 'when you stop it');
    });

    test('the last minute says very soon rather than a stale number', () {
      expect(sleepTimerSummary(const Duration(seconds: 20)), 'very soon');
      expect(sleepTimerSummary(const Duration(seconds: 60)), 'very soon');
    });

    test('rounds up, matching minutesLeft', () {
      expect(sleepTimerSummary(const Duration(seconds: 61)), 'in 2 minutes');
      expect(
        sleepTimerSummary(const Duration(minutes: 23, seconds: 30)),
        'in 24 minutes',
      );
    });
  });
}
