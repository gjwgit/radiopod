/// Stream end policy — reconnect, advance to the next station, or stop.
///
// Time-stamp: <Tuesday 2026-09-22 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

/// How long a station has to play before its ending is treated as a break in
/// transmission rather than a stream that never got going.
///
/// A bulletin or a music stream runs for minutes. A dead URL, a wrong codec
/// or a server refusing the connection gives up in well under this.

const realListenTime = Duration(seconds: 20);

/// How long to wait before giving up on a stream that never really played.
///
/// Only the [StreamEndAction.advance] and [StreamEndAction.stop] paths wait;
/// a reconnect happens at once, because that path is for a station that was
/// playing happily and every extra second is an audible hole.

const resumeGrace = Duration(seconds: 2);

/// What to do now that the current stream has ended.

enum StreamEndAction {
  /// Open the same station again. It was playing properly, so this is most
  /// likely a break in transmission rather than the end of the station.

  reconnect,

  /// Move to the next station in the queue.
  advance,

  /// Give up: there is nowhere useful to go.
  stop,
}

/// What to do now that a stream has ended, and the new failure tally.

typedef StreamEndDecision = ({StreamEndAction action, int failedAdvances});

/// Decide what should happen when the current stream ends.
///
/// Internet radio ends for two quite different reasons, and they are
/// indistinguishable at the moment they happen — both simply close the
/// connection.
///
/// 1. A BREAK IN TRANSMISSION. ABC News Radio closes the connection at the
///    end of each bulletin and carries straight on; the listener hears well
///    under a second of silence, and sometimes the last few seconds again.
///    That repeat is the giveaway, and it is why reconnecting is the right
///    move: it is Icecast's burst-on-connect, where the server hands a newly
///    connected listener a few seconds of already-broadcast audio so their
///    buffer fills at once. Hearing it means a fresh connection was made and
///    the station is still on air. Jumping to another station here is wrong.
///
/// 2. THE STATION IS DONE, or the URL was never any good.
///
/// NOTHING IN THE STREAM TELLS THE TWO APART. Both close the connection
/// after a long healthy run, and both report the same `completed` state.
/// Reconnecting to find out does not work either: NPR answers a reconnect by
/// replaying the same bulletin, so a stream that "comes back" proves
/// nothing. So the station carries the answer, as `reconnectOnEnd`, set once
/// by the listener from the Stations screen. The default is to move on,
/// which is right for a programme that finishes.
///
/// Playing time still matters on top of that flag. A reconnect is offered
/// only after [realListenTime] of real audio, so a station marked continuous
/// whose URL has gone stale cannot be retried for ever — the first failed
/// reconnect scores as a failure like any other and the queue advances.
///
/// Once there have been as many quick failures in a row as there are
/// stations in the queue, we have been all the way round without hearing
/// anything, and stopping is the honest outcome. A queue of one has nowhere
/// to advance to and stops rather than hammering a dead address.
///
/// Kept a pure function, separate from the audio handler, so this can be
/// tested without a media session.

StreamEndDecision decideStreamEnd({
  required int queueLength,
  required int failedAdvances,
  required Duration played,
  required bool reconnectOnEnd,
}) {
  // A station that ran properly is alive, whatever happens next, so its
  // ending must not count against the queue.

  final tally = played >= realListenTime ? 0 : failedAdvances;

  // Reconnect only for a station the listener has marked as continuous, and
  // only when it had really been playing. Both conditions matter: without
  // the flag we would replay NPR's bulletin, and without the playing time a
  // dead URL could be retried for ever.

  if (reconnectOnEnd && played >= realListenTime) {
    return (action: StreamEndAction.reconnect, failedAdvances: 0);
  }

  if (queueLength < 2 || tally >= queueLength) {
    return (action: StreamEndAction.stop, failedAdvances: tally);
  }

  return (action: StreamEndAction.advance, failedAdvances: tally + 1);
}
