/// RadioAudioHandler's stream ends — reconnect, move on, or stop.
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

part of 'radio_audio_handler.dart';

/// What [RadioAudioHandler] does when a station's stream runs out.
///
/// 20261016 gjw A part of the handler so it can reach the playback state,
/// and kept apart so radio_audio_handler.dart stays under the line limit.
/// The rule itself is the pure [decideStreamEnd]; read CLAUDE.md §7 and §8
/// before changing anything here.

extension StreamEndHandling on RadioAudioHandler {
  void _cancelPendingAdvance() {
    _endTimer?.cancel();
    _endTimer = null;
  }

  /// A stream has run out. Reconnect, move on, or stop.
  ///
  /// A STATION THAT WAS PLAYING PROPERLY IS RECONNECTED, NOT ABANDONED. ABC
  /// News Radio closes the connection at the end of each bulletin and is
  /// still on air immediately afterwards; the player does NOT pick it up by
  /// itself, so RadioPod has to open it again. Waiting instead of
  /// reconnecting, as an earlier version did, just produced a long silence
  /// and then the wrong station.
  ///
  /// [decideStreamEnd] holds the rule that separates that case from a
  /// station that has genuinely finished.

  void _onStreamEnded() {
    if (_currentStation == null) return;

    // A station the user stopped has not "ended", so it must not reconnect,
    // advance to the next station, or count towards the failure tally.

    if (_stopped) return;

    // A stream can report completed more than once. The first report starts
    // the clock; later ones must not restart it.

    if (_endTimer != null) return;

    final played = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);

    // Read the flag from the library rather than from _currentStation, which
    // is a snapshot taken when playback started. Otherwise turning the
    // setting on for the station playing right now would not take effect
    // until it was started again.

    final station = _stations
        .where((s) => s.id == _currentStation!.id)
        .firstOrNull;
    final reconnectOnEnd =
        station?.reconnectOnEnd ?? _currentStation!.reconnectOnEnd;

    final decision = decideStreamEnd(
      queueLength: _queueStations.length,
      failedAdvances: _failedAdvances,
      played: played,
      reconnectOnEnd: reconnectOnEnd,
    );
    _failedAdvances = decision.failedAdvances;

    debugPrint(
      '[RadioAudioHandler] ${_currentStation?.name} ended after '
      '${played.inSeconds}s (reconnectOnEnd: $reconnectOnEnd) '
      '-> ${decision.action.name}',
    );

    if (played < realListenTime) unawaited(_reportGeoBlock(_currentStation!));

    // A reconnect happens AT ONCE. This is a station that was playing
    // happily a moment ago, so every extra second is an audible hole where
    // there used to be well under one.

    if (decision.action == StreamEndAction.reconnect) {
      unawaited(_reconnectCurrent());

      return;
    }

    // The other two paths do pause first, in case the player picks the
    // stream back up by itself and saves us the trouble. The decision is
    // carried through rather than recomputed, so time spent waiting can
    // never be mistaken for time spent playing.

    _endTimer = Timer(resumeGrace, () => _carryOut(decision.action));
  }

  /// Find out whether [station] ended early because it refuses our country.
  ///
  /// 20261014 gjw Asked only after a QUICK end, so a station that plays
  /// normally never costs a second connection. The queue still moves on as
  /// before; this only explains why, since a blocked station otherwise
  /// looks exactly like a broken one.

  Future<void> _reportGeoBlock(Station station) async {
    // 20261014 gjw Once per station a session. A server's country rule does
    // not change between breaks, and a station like ABC National Radio that
    // breaks often should not open a second connection at every one.

    if (!_geoChecked.add(station.id)) return;

    final country = await probeGeoBlock(station.url);
    if (country == null) return;

    _geoBlocks.add((station: station.name, country: country));
  }

  /// Open the current station again after a break in transmission.
  ///
  /// [_startedAt] is reset BEFORE the attempt, so that a connection which
  /// also ends immediately scores as a failure and the queue moves on,
  /// rather than inheriting the long healthy run that earned the reconnect.
  /// That is what stops a station which ends over and over from being
  /// reconnected for ever.

  Future<void> _reconnectCurrent() async {
    final station = _currentStation;
    if (station == null) return;

    _startedAt = DateTime.now();
    try {
      await _player.setUrl(station.url);
      await _player.play();
    } catch (e) {
      debugPrint('[RadioAudioHandler] reconnect to ${station.name} failed: $e');

      // The station really has gone. Decide again, now scoring as a failure.

      _onStreamEnded();
    }
  }

  /// Carry out an advance or a stop, unless the stream came back meanwhile.

  void _carryOut(StreamEndAction action) {
    _cancelPendingAdvance();
    if (_currentStation == null || _resumed) return;

    if (action == StreamEndAction.stop) {
      stop();

      return;
    }

    // Nothing awaits this, and playStation rethrows when a stream will not
    // open at all. Such a station never reaches `completed`, so without
    // catching it here the chain would stop dead on the first bad URL — and
    // the throw would surface as an unhandled async error.
    //
    // Straight back to _carryOut rather than through _onStreamEnded: a
    // stream that refused to open has nothing to come back from, so waiting
    // out another grace period would only add silence between dead stations.

    unawaited(
      skipToNext().catchError((Object e) {
        debugPrint('[RadioAudioHandler] auto-advance could not start: $e');
        _carryOut(StreamEndAction.advance);
      }),
    );
  }
}
