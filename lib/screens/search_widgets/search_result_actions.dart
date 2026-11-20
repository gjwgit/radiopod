/// SearchResultActions — the buttons at the end of a search result's row.
///
// Time-stamp: <Sunday 2026-10-18 06:00:00 +1100 Graham Williams>
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

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/search_widgets/search_result_dialog.dart';

/// Information, then Save — or a tick once [saved].

class SearchResultActions extends StatelessWidget {
  final Station station;
  final bool saved;
  final VoidCallback onSave;

  const SearchResultActions({
    super.key,
    required this.station,
    required this.saved,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final kind = station.isPodcast ? 'podcast' : 'station';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownTooltip(
          message:
              '''

          **Information**

          What is known about this $kind — its details, links and, for a
          podcast, what it is about — before you decide to save it.

          ''',
          child: IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showSearchResultDialog(
              context,
              station,
              saved: saved,
              onSave: onSave,
            ),
          ),
        ),
        if (saved)
          const MarkdownTooltip(
            message: '''

            **Already saved**

            This is in your library. Find it on the Stations screen to play
            it or add it to a playlist.

            ''',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.check),
            ),
          )
        else
          MarkdownTooltip(
            message: '''

            **Save**

            Add this to your library, at the top of your Stations. It is
            written encrypted to your Solid Pod when you are logged in.

            ''',
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onSave,
            ),
          ),
      ],
    );
  }
}
