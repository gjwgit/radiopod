/// CastTile — one episode on a podcast's page.
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

import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:radiopod/models/cast.dart';
import 'package:radiopod/utils/cast_text.dart';

/// A cast row: title, when and how long, progress, and the show notes.
///
/// 20261016 gjw A PLAYED CAST STAYS, GREYED. It is still worth seeing — to
/// find something heard last week, or to hear it again — so it is dimmed
/// rather than removed, and a tap still plays it. A SKIPPED (disabled) cast is
/// dimmed the same way; the ring's glyph says which it is, a tick or a
/// barred circle. Neither is played when the podcast is working backwards
/// through its casts.
///
/// A plain widget, given everything it draws, so it can be tested without
/// a media session, like StationTile.

class CastTile extends StatefulWidget {
  final Cast cast;

  /// This cast is the one the media session is on.

  final bool current;
  final bool playing;

  final VoidCallback onTap;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<bool> onPlayed;

  /// Show the episode's whole text.

  final VoidCallback onInfo;

  const CastTile({
    super.key,
    required this.cast,
    required this.onTap,
    required this.onEnabled,
    required this.onPlayed,
    required this.onInfo,
    this.current = false,
    this.playing = false,
  });

  @override
  State<CastTile> createState() => _CastTileState();
}

class _CastTileState extends State<CastTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.cast;
    final dimmed = !c.available && !widget.current;

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: ListTile(
        selected: widget.current,
        selectedTileColor: cs.primaryContainer.withValues(alpha: 0.38),
        leading: MarkdownTooltip(
          message:
              '''

          **Play**

          Tap to play this episode${c.played ? ' again' : ''}.

          **Double tap** to mark it as ${_playedTurn(c)}.
          The ring shows how much has been heard: a tick once played, a
          barred circle when skipped.

          ''',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onDoubleTap: () => widget.onPlayed(!c.played),
            child: _leading(cs, c),
          ),
        ),
        title: Text(
          c.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: widget.current ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              castSummary(c),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            if (c.description.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  c.description,
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
        isThreeLine: c.description.isNotEmpty,
        onTap: widget.onTap,
        // 20261026 gjw No switch and no menu: the row was crowded on a
        // phone. A DOUBLE TAP on the play ring marks the episode played or
        // not, and on the information button skips it or brings it back.
        // Each single tap does what it did; it waits a moment first, to
        // see whether a second is coming.
        trailing: MarkdownTooltip(
          message:
              '''

          **Episode information**

          Tap to read the whole of what the publisher says about this
          episode. The list shows only its first lines.

          **Double tap** to ${_skipTurn(c)}.
          Swiping the row left skips it, and right brings it back.

          ''',
          child: GestureDetector(
            onDoubleTap: () => widget.onEnabled(c.disabled),
            child: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: widget.onInfo,
            ),
          ),
        ),
      ),
    );
  }

  /// What a double tap on the ring does to [c], for its tooltip.

  String _playedTurn(Cast c) => c.played
      ? 'not played, to hear it again in its turn'
      : 'played, so it is passed over';

  /// What a double tap on the information button does to [c].

  String _skipTurn(Cast c) => c.disabled
      ? 'bring this skipped episode back, so it is played in its turn'
      : 'skip this episode, so it is passed over when the podcast plays';

  /// A ring showing how much has been heard, with a play or pause glyph
  /// when this cast is on air.

  Widget _leading(ColorScheme cs, Cast c) {
    final d = c.duration;
    final heard = c.played
        ? 1.0
        : d == null || d == Duration.zero
        ? 0.0
        : (c.position.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: heard,
            strokeWidth: 3,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          Icon(
            widget.current && widget.playing
                ? Icons.pause
                : c.played
                ? Icons.check
                : c.disabled
                ? Icons.block
                : Icons.play_arrow,
            size: 20,
            color: cs.primary,
          ),
        ],
      ),
    );
  }
}
