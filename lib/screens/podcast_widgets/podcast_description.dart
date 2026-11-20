/// PodcastDescription — what a podcast is about, atop its Episodes page.
///
// Time-stamp: <Sunday 2026-10-25 10:00:00 +1100 Graham Williams>
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

/// The podcast's own description, from its feed: four lines, and the rest
/// with a tap.
///
/// 20261025 gjw The same text Search shows in its information dialog, so a
/// saved podcast says what it is about where its episodes are listed. Folded
/// to four lines because some publishers write a page, and the episodes are
/// what the page is for.

class PodcastDescription extends StatefulWidget {
  const PodcastDescription(this.text, {super.key});

  final String text;

  @override
  State<PodcastDescription> createState() => _PodcastDescriptionState();
}

class _PodcastDescriptionState extends State<PodcastDescription> {
  bool _expanded = false;

  static const _folded = 4;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Offer the tap only when there is more to show.

        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _folded,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final long = painter.didExceedMaxLines;
        painter.dispose();

        final text = Text(
          widget.text,
          style: style,
          maxLines: _expanded ? null : _folded,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        );
        if (!long) return text;

        return MarkdownTooltip(
          message: _expanded
              ? '**Less**\n\nTap to fold the description back to four lines.'
              : '**More**\n\nTap to read the whole description.',
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: text,
          ),
        );
      },
    );
  }
}
