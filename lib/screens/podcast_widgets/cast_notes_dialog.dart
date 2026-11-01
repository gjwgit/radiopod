/// CastNotesDialog — the whole text of one episode, from its Info button.
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

import 'package:gap/gap.dart';

import 'package:radiopod/models/cast.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/podcast_feed.dart';
import 'package:radiopod/utils/cast_text.dart';

/// Show the whole text of [cast] of [podcast].
///
/// 20261025 gjw The list shows two lines of a summary kept to 400
/// characters, which is all `casts.ttl` holds. The summary shows at once;
/// when it was cut short the full show notes are fetched from the feed and
/// take its place, with their paragraphs. A fetch that fails leaves the
/// summary and says so.

Future<void> showCastNotes(
  BuildContext context, {
  required Station podcast,
  required Cast cast,
}) => showDialog<void>(
  context: context,
  builder: (context) => _CastNotesDialog(podcast: podcast, cast: cast),
);

class _CastNotesDialog extends StatelessWidget {
  const _CastNotesDialog({required this.podcast, required this.cast});

  final Station podcast;
  final Cast cast;

  bool get _cut => cast.description.endsWith('…');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);

    return AlertDialog(
      title: Text(cast.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${podcast.name} · ${castSummary(cast)}', style: small),
              const Gap(12),
              if (!_cut)
                SelectableText(
                  cast.description.isEmpty
                      ? 'The publisher gives no description of this episode.'
                      : cast.description,
                )
              else
                FutureBuilder<String?>(
                  future: fetchCastNotes(podcast.url, cast.guid),
                  builder: (context, snap) {
                    final full = snap.data;
                    final waiting =
                        snap.connectionState != ConnectionState.done;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(full ?? cast.description),
                        if (waiting) ...[
                          const Gap(12),
                          const LinearProgressIndicator(),
                          const Gap(4),
                          Text(
                            'Fetching the full text from the publisher…',
                            style: small,
                          ),
                        ] else if (full == null) ...[
                          const Gap(12),
                          Text(
                            snap.hasError
                                ? 'The full text could not be fetched from '
                                      'the publisher.'
                                : 'The publisher no longer lists this '
                                      'episode, so this summary is all '
                                      'there is.',
                            style: small,
                          ),
                        ],
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
