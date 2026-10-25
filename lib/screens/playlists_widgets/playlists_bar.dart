/// PlaylistsBar — the filter and Manage playlists atop the Playlists page.
///
// Time-stamp: <Sunday 2026-10-25 14:00:00 +1100 Graham Williams>
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

import 'package:radiopod/screens/playlists_widgets/manage_playlists_dialog.dart';

/// The Playlists filter, drawn like the Stations one, and to its right the
/// button that opens the grid of stations against playlists, which starts
/// with the same filter. [onChanged] is called on every edit, and on Clear.
/// [trailing], the Stop/Play button, sits at the right as on Stations.

class PlaylistsBar extends StatelessWidget {
  const PlaylistsBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.canManage,
    this.trailing,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  /// False while there is no playlist or no station to tick.

  final bool canManage;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.filter_list),
              hintText: 'Filter your playlists and their stations.',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: controller.text.isEmpty
                  ? null
                  : MarkdownTooltip(
                      message: '''

                      **Clear**

                      Clear the filter and list every playlist.

                      ''',
                      child: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          onChanged();
                        },
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        MarkdownTooltip(
          message: '''

          **Manage playlists**

          Every station and podcast in your library against every playlist,
          as a grid: tick a box to put a station in that playlist, untick it
          to take it out. The grid starts with this page's filter. You need
          at least one playlist and one station.

          ''',
          child: IconButton.filledTonal(
            icon: const Icon(Icons.playlist_add_check),
            onPressed: canManage
                ? () => showManagePlaylists(context, filter: controller.text)
                : null,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}
