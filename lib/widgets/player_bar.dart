/// PlayerBar — the now-playing bar shown on every screen.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:flutter/material.dart';

import 'package:audio_service/audio_service.dart';
import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:radiopod/services/player.dart';

/// A compact transport bar driven entirely by the audio handler's streams.
///
/// It reads [AudioHandler.mediaItem] and [AudioHandler.playbackState] rather
/// than any app state, which is what keeps it honest: when a station is
/// started from Android Auto, the headset button or the lock screen, this bar
/// updates too, because it is watching the same media session the car is.
///
/// The bar collapses to nothing when no station has been started, so it costs
/// no screen space until it has something to say.

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final handler = Player.handler;

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, mediaSnapshot) {
        final item = mediaSnapshot.data;
        if (item == null) return const SizedBox.shrink();

        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;

            return _bar(context, item, state);
          },
        );
      },
    );
  }

  Widget _bar(BuildContext context, MediaItem item, PlaybackState? state) {
    final cs = Theme.of(context).colorScheme;
    final playing = state?.playing ?? false;
    final processing = state?.processingState;
    final connecting =
        processing == AudioProcessingState.loading ||
        processing == AudioProcessingState.buffering;
    final failed = processing == AudioProcessingState.error;

    return Material(
      color: cs.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              _statusIcon(cs, connecting: connecting, failed: failed),
              const Gap(12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _status(
                        item,
                        playing: playing,
                        connecting: connecting,
                        failed: failed,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: failed
                            ? cs.error
                            : _showingTrack(item, playing: playing)
                            ? cs.primary
                            : cs.onSurfaceVariant,
                        fontSize: 12,
                        // The song on air is the live part of this bar, so it
                        // is set apart from the station's static details.
                        fontWeight: _showingTrack(item, playing: playing)
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              MarkdownTooltip(
                message: playing
                    ? '''

                    **Stop**

                    Stop the stream. Live radio has no pause — stopping and
                    starting again reconnects you to what is on air now.

                    '''
                    : '''

                    **Play**

                    Reconnect to this station and start listening again.

                    ''',
                child: IconButton(
                  iconSize: 32,
                  icon: Icon(playing ? Icons.stop_circle : Icons.play_circle),
                  color: cs.primary,
                  onPressed: playing
                      ? Player.handler.stop
                      : Player.handler.play,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A small leading indicator: a spinner while connecting, otherwise the
  /// station logo placeholder.

  Widget _statusIcon(
    ColorScheme cs, {
    required bool connecting,
    required bool failed,
  }) {
    if (connecting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Icon(
      failed ? Icons.error_outline : Icons.radio,
      color: failed ? cs.error : cs.primary,
    );
  }

  /// The second line: the song on air when the stream announces one.
  ///
  /// Otherwise it reports what is happening, and once playing falls back to
  /// the station's own country, codec and bitrate. Many streams send no ICY
  /// metadata, and none of them do on Linux or Windows desktop, so the
  /// fallback is the common case rather than an edge case.

  String _status(
    MediaItem item, {
    required bool playing,
    required bool connecting,
    required bool failed,
  }) {
    if (failed) return 'Could not connect to this station.';
    if (connecting) return 'Connecting…';
    if (!playing) return 'Stopped';

    return item.artist ?? 'Playing';
  }

  /// True when the second line is a live track rather than station details.
  ///
  /// The handler puts the track in extras as well as in the artist slot
  /// precisely so the two can be told apart here.

  bool _showingTrack(MediaItem item, {required bool playing}) =>
      playing && item.extras?['track'] != null;
}
