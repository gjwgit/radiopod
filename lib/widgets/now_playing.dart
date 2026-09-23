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

import 'package:radiopod/services/player.dart';

/// What the media session is doing, reduced to what a station row needs.

class NowPlaying {
  /// The station on air, or null when nothing has been started.

  final String? stationId;

  /// The song the stream announced, when it has announced one.

  final String? track;

  final bool playing;
  final bool connecting;
  final bool failed;

  const NowPlaying({
    this.stationId,
    this.track,
    this.playing = false,
    this.connecting = false,
    this.failed = false,
  });

  /// True when [id] is the station the session is currently on.

  bool isCurrent(String id) => stationId != null && stationId == id;
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: Player.handler.mediaItem,
      builder: (context, itemSnapshot) {
        final item = itemSnapshot.data;

        return StreamBuilder<PlaybackState>(
          stream: Player.handler.playbackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            final processing = state?.processingState;

            return builder(
              context,
              NowPlaying(
                stationId: item?.extras?['stationId'] as String?,
                track: item?.extras?['track'] as String?,
                playing: state?.playing ?? false,
                connecting:
                    processing == AudioProcessingState.loading ||
                    processing == AudioProcessingState.buffering,
                failed: processing == AudioProcessingState.error,
              ),
            );
          },
        );
      },
    );
  }
}
