/// Tests for what the media session is told about the player's state.
///
// Time-stamp: <Tuesday 2026-10-06 17:00:00 +1100 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
//
/// Authors: Graham Williams

library;

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/services/radio_audio_handler.dart';

AudioProcessingState _reported(
  AudioProcessingState state, {
  bool stopped = false,
  bool hasStation = true,
}) => reportedProcessingState(state, stopped: stopped, hasStation: hasStation);

void main() {
  // 20261006 gjw The whole point is one transition. audio_service reads ANY
  // move into idle as the session being over and calls
  // deactivateMediaSession() + stopSelf() (AudioService.java:565, 355). A
  // station switch passes through idle, so every Next in the car tore the
  // media service down and bounced the driver back to the station list.

  group('a station switch', () {
    test('never reports idle, because that stops the service', () {
      expect(
        _reported(AudioProcessingState.idle),
        AudioProcessingState.loading,
      );
    });

    test('loading reaches the car as STATE_CONNECTING, which is the truth', () {
      // Named rather than asserted on: loading is the one substitute that
      // says "a station is on its way" instead of "there is no session".

      expect(
        _reported(AudioProcessingState.idle),
        isNot(AudioProcessingState.idle),
      );
    });
  });

  group('a real stop', () {
    test('does report idle, so the notification goes away', () {
      expect(
        _reported(AudioProcessingState.idle, stopped: true),
        AudioProcessingState.idle,
      );
    });

    test('before anything has played, idle is honest', () {
      expect(
        _reported(AudioProcessingState.idle, hasStation: false),
        AudioProcessingState.idle,
      );
    });
  });

  group('every other state is passed straight through', () {
    for (final state in AudioProcessingState.values) {
      if (state == AudioProcessingState.idle) continue;

      test('${state.name} is untouched while playing', () {
        expect(_reported(state), state);
      });

      test('${state.name} is untouched after a stop', () {
        expect(_reported(state, stopped: true), state);
      });
    }
  });

  // A stream that ENDS reports completed, not idle. That must keep reaching
  // the session unchanged: it is what the stream-end policy reads to decide
  // between reconnecting and moving on (CLAUDE.md §8), and unlike idle it
  // does not make audio_service stop the service.

  test('completed is not rewritten, whatever else is true', () {
    expect(
      _reported(AudioProcessingState.completed),
      AudioProcessingState.completed,
    );
    expect(
      _reported(AudioProcessingState.completed, stopped: true),
      AudioProcessingState.completed,
    );
  });
}
