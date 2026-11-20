/// StationPlaylistsDialog — tick the playlists one station belongs in.
///
// Time-stamp: <Monday 2026-11-16 10:00:00 +1100 Graham Williams>
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

import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/playlists_widgets/playlist_name_dialog.dart';
import 'package:radiopod/services/app_provider.dart';

/// Show the playlists [station] can go in, each ticked where it already is.

Future<void> showStationPlaylists(BuildContext context, Station station) =>
    showDialog<void>(
      context: context,
      builder: (_) => StationPlaylistsDialog(station: station),
    );

/// A tick per playlist for one station.
///
/// 20261116 gjw Opened by a swipe right on a Stations row. Manage playlists
/// sorts the whole library in one pass; this is the same tick for the one
/// station the user is looking at. Each tick writes through at once, as the
/// grid's do, so there is only Close.

class StationPlaylistsDialog extends StatelessWidget {
  const StationPlaylistsDialog({super.key, required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final playlists = provider.playlists;

    return AlertDialog(
      title: Text('Playlists for ${station.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: playlists.isEmpty
            ? const Text(
                'You have no playlists yet. Create one with New playlist '
                'and this station will be put in it.',
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in playlists)
                      CheckboxListTile(
                        title: Text(p.name),
                        value: p.stationIds.contains(station.id),
                        onChanged: (on) => on ?? false
                            ? provider.addToPlaylist(p.id, station.id)
                            : provider.removeFromPlaylist(p.id, station.id),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        MarkdownTooltip(
          message: '''

          **New playlist**

          Create a playlist with this station already in it. Add more
          stations to it the same way, or from Manage playlists.

          ''',
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New playlist'),
            onPressed: () => _create(context, provider),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, AppProvider provider) async {
    final name = await showPlaylistNameDialog(context, title: 'New playlist');
    if (name == null) return;

    await provider.addPlaylist(name, stationIds: [station.id]);
  }
}
