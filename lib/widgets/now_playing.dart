/// NowPlaying — a snapshot of the media session, for list rows to read.
///
// Time-stamp: <Wednesday 2026-09-23 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:flutter/material.dart';

import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

import 'package:radiopod/services/player.dart';

/// What the media session is doing, reduced to what a station row needs.

class NowPlaying {
  /// The station on air, or null when nothing has been started.

  final String? stationId;

  /// The song the stream announced, when it has announced one.

  final String? track;

  final bool playing;

  /// Opening the connection to the stream.

  final bool connecting;

  /// Connected, and filling the buffer before (or while) sound comes out.

  final bool loading;

  /// Loaded and ready but not playing: a pause that kept the connection.

  final bool paused;

  final bool failed;

  const NowPlaying({
    this.stationId,
    this.track,
    this.playing = false,
    this.connecting = false,
    this.loading = false,
    this.paused = false,
    this.failed = false,
  });

  /// True when [id] is the station the session is currently on.

  bool isCurrent(String id) => stationId != null && stationId == id;

  // 20260923 gjw Value equality exists so the stream below can be made
  // `distinct`. Without it the whole station list rebuilt on every playback
  // event — several a second while buffering — for a snapshot that had not
  // actually changed.

  @override
  bool operator ==(Object other) =>
      other is NowPlaying &&
      other.stationId == stationId &&
      other.track == track &&
      other.playing == playing &&
      other.connecting == connecting &&
      other.loading == loading &&
      other.paused == paused &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(
    stationId,
    track,
    playing,
    connecting,
    loading,
    paused,
    failed,
  );
}

/// Rebuilds [builder] whenever the media session changes.
///
/// Wraps the two streams a station list cares about — which station is on air
/// and what the transport is doing — so each screen subscribes ONCE rather
/// than once per row, and so [StationTile] itself stays a plain widget with
/// no dependency on a running AudioService. That matters: the tile's tests
/// pump it directly, with no media session anywhere.

class NowPlayingBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, NowPlaying now) builder;

  const NowPlayingBuilder({super.key, required this.builder});

  /// The station whose current start has reached `ready`, if [_started].

  static String? _startedId;
  static bool _started = false;

  /// One stream of exactly what a row needs, and no more.
  ///
  /// Combining the two sources here rather than nesting two StreamBuilders
  /// lets the result be made `distinct`, so a rebuild happens only when
  /// something a row actually draws has changed.

  static Stream<NowPlaying> get _stream => Rx.combineLatest2(
    Player.handler.mediaItem,
    Player.handler.playbackState,
    (MediaItem? item, PlaybackState state) {
      final processing = state.processingState;
      final stationId = item?.extras?['stationId'] as String?;

      // 20260929 tc BUFFERING IS NOT LOADING ONCE THE STATION HAS STARTED.
      // The players report `buffering` whenever the buffer dips, and on a
      // live stream that happens routinely while sound is still coming out,
      // so the row said "Loading" over audible music. Loading now means only
      // the stretch between connecting and the first `ready` of this start.
      // After that a dip still counts as Playing. Opening the station again,
      // stopping it, or switching station clears the latch.
      //
      // Static rather than per stream because the stream is rebuilt with its
      // StreamBuilder, and a fresh latch would start by misreading the
      // replayed state as Loading.

      if (stationId != _startedId) _started = false;
      _startedId = stationId;
      if (processing == AudioProcessingState.ready) {
        _started = true;
      } else if (processing != AudioProcessingState.buffering) {
        _started = false;
      }

      return NowPlaying(
        stationId: stationId,
        track: item?.extras?['track'] as String?,
        playing: state.playing,
        connecting: processing == AudioProcessingState.loading,
        loading: processing == AudioProcessingState.buffering && !_started,
        paused: processing == AudioProcessingState.ready && !state.playing,
        failed: processing == AudioProcessingState.error,
      );
    },
  ).distinct();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NowPlaying>(
      stream: _stream,
      builder: (context, snapshot) =>
          builder(context, snapshot.data ?? const NowPlaying()),
    );
  }
}
