/// OnAirTrack — the whole title of what a station has on air.
///
// Time-stamp: <Wednesday 2026-10-28 12:00:00 +1100 Graham Williams>
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
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:radiopod/widgets/now_playing.dart';

/// The track [stationId] has on air, followed as the session changes, or
/// nothing while another station, or none, is on.
///
/// 20261028 gjw For Properties. The row's second line holds the track to one
/// line, and a long one (a classical work, a talk programme's segment) is
/// cut short there.

class OnAirTrackFollower extends StatelessWidget {
  final String stationId;

  const OnAirTrackFollower({super.key, required this.stationId});

  @override
  Widget build(BuildContext context) => NowPlayingBuilder(
    builder: (context, now) => now.isCurrent(stationId)
        ? OnAirTrack(track: now.track)
        : const SizedBox.shrink(),
  );
}

/// The track in full, selectable and with a Copy button, or a word that the
/// station names none.
///
/// Apart from the media session so it can be tested. Many streams send no
/// metadata at all, so saying so is the common case, and tells the listener
/// the gap is the station's and not the app's.

class OnAirTrack extends StatelessWidget {
  final String? track;

  const OnAirTrack({super.key, this.track});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = track?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('On air now', style: Theme.of(context).textTheme.labelLarge),
          const Gap(8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: now.isEmpty
                ? Text(
                    'This station is not saying what is playing.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                : Row(
                    children: [
                      Expanded(child: SelectableText(now)),
                      _copy(context, now),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _copy(BuildContext context, String now) => MarkdownTooltip(
    message: '''

    **Copy**

    Copy what is on air to the clipboard, to look it up later.

    ''',
    child: IconButton(
      icon: const Icon(Icons.copy, size: 16),
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: now));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Track copied.')));
        }
      },
    ),
  );
}
