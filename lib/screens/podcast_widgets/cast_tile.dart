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
/// dimmed the same way; the switch says which it is. Neither is played when
/// the podcast is working backwards through its casts.
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

  const CastTile({
    super.key,
    required this.cast,
    required this.onTap,
    required this.onEnabled,
    required this.onPlayed,
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
        leading: _leading(cs, c),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MarkdownTooltip(
              message: '''

              **Play this episode**

              On, this episode is played in its turn, newest first. Off, it
              is skipped, though a tap still plays it. Swipe the row left to
              skip it, and right to bring it back.

              ''',
              child: Switch(value: !c.disabled, onChanged: widget.onEnabled),
            ),
            MarkdownTooltip(
              message: '''

              **Episode actions**

              Mark this episode as played, so it is passed over, or as not
              played, to hear it again in its turn.

              ''',
              // An empty tooltip turns off the menu's own plain "Show menu",
              // which would otherwise show alongside this one.
              child: PopupMenuButton<bool>(
                tooltip: '',
                onSelected: widget.onPlayed,
                itemBuilder: (_) => [
                  c.played
                      ? const PopupMenuItem(
                          value: false,
                          child: Text('Mark as not played'),
                        )
                      : const PopupMenuItem(
                          value: true,
                          child: Text('Mark as played'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                : Icons.play_arrow,
            size: 20,
            color: cs.primary,
          ),
        ],
      ),
    );
  }
}
