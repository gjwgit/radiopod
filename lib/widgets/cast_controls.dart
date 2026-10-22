/// CastControls — the timeline, shown only while a cast plays.
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
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:radiopod/services/cast_playback.dart';
import 'package:radiopod/services/player.dart';

/// Back 15 s, a seek bar with the time, and forward 30 s.
///
/// 20261016 gjw Nothing at all while a station plays or nothing does, so
/// radio looks exactly as it did. A cast has a timeline and the listener
/// expects to move about in it; the row above still says what is playing,
/// as it does for a station.
///
/// Position ticks every half second from the session's own extrapolation,
/// in a widget of its own, so only this bar repaints — not the list.

class CastControls extends StatelessWidget {
  const CastControls({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: Player.handler.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        if (item?.extras?['castGuid'] == null) return const SizedBox.shrink();

        return StreamBuilder<Duration>(
          stream: Stream.periodic(
            const Duration(milliseconds: 500),
            (_) => Player.handler.playbackState.value.position,
          ),
          builder: (context, pos) =>
              _bar(context, pos.data ?? Duration.zero, item!.duration),
        );
      },
    );
  }

  static const _skipIconSize = 44.0;
  static const _skipButtonSize = BoxConstraints(minWidth: 64, minHeight: 64);

  Widget _bar(BuildContext context, Duration position, Duration? length) {
    final cs = Theme.of(context).colorScheme;
    final max = (length ?? Duration.zero).inMilliseconds.toDouble();
    final value = position.inMilliseconds.toDouble().clamp(0.0, max);
    final style = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);

    // 20261023 gjw The skip buttons are large, with a gap below the bar,
    // because on a small phone the default 48 px button sat so close to the
    // first station that a tap on Back or Forward often started it instead.

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        children: [
          MarkdownTooltip(
            message: '**Back ${castSkipBack.inSeconds} seconds**',
            child: IconButton(
              iconSize: _skipIconSize,
              constraints: _skipButtonSize,
              icon: _SkipIcon(castSkipBack.inSeconds, forward: false),
              onPressed: Player.handler.rewind,
            ),
          ),
          Text(clockTime(position), style: style),
          Expanded(
            child: max <= 0
                ? const LinearProgressIndicator(value: null)
                : Slider(
                    value: value,
                    max: max,
                    onChanged: (v) =>
                        Player.handler.seek(Duration(milliseconds: v.round())),
                  ),
          ),
          Text(length == null ? '--:--' : clockTime(length), style: style),
          MarkdownTooltip(
            message: '**Forward ${castSkipForward.inSeconds} seconds**',
            child: IconButton(
              iconSize: _skipIconSize,
              constraints: _skipButtonSize,
              icon: _SkipIcon(castSkipForward.inSeconds, forward: true),
              onPressed: Player.handler.fastForward,
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular arrow with the seconds inside it.
///
/// 20261023 gjw Both buttons draw the SAME arrow, mirrored for forward.
/// Material's forward_30 draws a smaller circle than the bare replay arrow,
/// to fit its number, so the pair looked mismatched, and Material has no
/// replay_15 to pair it with.

class _SkipIcon extends StatelessWidget {
  const _SkipIcon(this.seconds, {required this.forward});

  final int seconds;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size ?? 24;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.flip(flipX: forward, child: const Icon(Icons.replay)),
          Padding(
            padding: EdgeInsets.only(top: size * 0.1),
            child: Text(
              '$seconds',
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.bold,
                color: IconTheme.of(context).color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `4:05` or `1:02:03`, as a player's clock reads.

String clockTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');

  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
