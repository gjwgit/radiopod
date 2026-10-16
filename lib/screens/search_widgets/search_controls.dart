/// SearchControls — what to search for, how, and the box to type it in.
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

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:radiopod/services/radio_browser.dart';

/// Radio stations or podcasts: which directory Search asks.

enum SearchKind {
  radio('Radio', Icons.radio),
  podcast('Podcast', Icons.podcasts);

  const SearchKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The top of the Search screen.
///
/// 20261016 gjw Radio | Podcast first, since it decides which directory is
/// asked and so what the rest means. Name, Genre and Location, and `@place`,
/// are Radio-Browser's; Podcast Index has one search over titles, authors
/// and topics, so for podcasts that row is not shown at all rather than
/// shown and ignored.

class SearchControls extends StatelessWidget {
  final SearchKind kind;
  final SearchField field;
  final TextEditingController controller;
  final bool searching;
  final ValueChanged<SearchKind> onKind;
  final ValueChanged<SearchField> onField;
  final VoidCallback onSearch;

  /// Beside the search box: the stop/play button.

  final Widget trailing;

  const SearchControls({
    super.key,
    required this.kind,
    required this.field,
    required this.controller,
    required this.searching,
    required this.onKind,
    required this.onField,
    required this.onSearch,
    required this.trailing,
  });

  bool get _podcast => kind == SearchKind.podcast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<SearchKind>(
          segments: [
            for (final k in SearchKind.values)
              ButtonSegment(value: k, icon: Icon(k.icon), label: Text(k.label)),
          ],
          selected: {kind},
          onSelectionChanged: (s) => onKind(s.first),
        ),
        if (!_podcast) ...[
          const Gap(8),
          SegmentedButton<SearchField>(
            segments: [
              for (final f in SearchField.values)
                ButtonSegment(value: f, label: Text(f.label)),
            ],
            selected: {field},
            onSelectionChanged: (s) => onField(s.first),
          ),
        ],
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: _podcast
                      ? 'Podcast name, author or topic, e.g. Future Tense'
                      : field.hint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: MarkdownTooltip(
                    message: _podcast ? _podcastHelp : _radioHelp,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: searching ? null : onSearch,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(8),
            trailing,
          ],
        ),
      ],
    );
  }
}

const _radioHelp = '''

**Search**

Ask the community-run Radio-Browser database for matching stations. Only
your search text and the app name are sent.

Put **@** before a place to search only there, as in `@sydney news`. The
other words then match the station name on *Name*, the genre on *Genre*,
and either on *Location*. A place of several words needs quotes:
`@"new york" jazz`.

On *Location* the text without an **@** is the place: a country such as
`Australia` or a region such as `Victoria`.

''';

const _podcastHelp = '''

**Search podcasts**

Ask the open Podcast Index directory for podcasts whose title, author or
topic matches. Only your search text and the app name are sent.

Tap a podcast to hear its latest episode, or save it to follow it. Once
saved, its episodes come straight from the podcast's own publisher.

''';
