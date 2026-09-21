/// PlaylistsScreen — create and edit named groups of stations.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/playlists_widgets/playlist_name_dialog.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';
import 'package:radiopod/widgets/startup_overlay.dart';
import 'package:radiopod/widgets/station_tile.dart';

/// Playlists, each expanding to show the stations it holds.
///
/// Playlists matter beyond tidiness: they are the folders Android Auto shows
/// in the car, and the unit an M3U or PLS file exports to. Stations are added
/// to a playlist from the Stations screen, so this screen only creates,
/// renames, reorders by removal, and deletes.

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return StartupOverlay(
      phase: provider.startupPhase,
      child: Scaffold(
        body: provider.busy
            ? const Center(child: CircularProgressIndicator())
            : provider.playlists.isEmpty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  for (final p in provider.playlists)
                    _tile(context, provider, p),
                ],
              ),
        floatingActionButton: MarkdownTooltip(
          message: '''

          **New playlist**

          Create an empty playlist, then add stations to it from the Stations
          screen. Playlists are what Android Auto lists in the car.

          ''',
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('New playlist'),
            onPressed: () => _create(context, provider),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music, size: 56, color: cs.onSurfaceVariant),
            const Gap(16),
            Text(
              'No playlists yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(8),
            Text(
              'Create a playlist to group stations together. Playlists are '
              'the folders you browse in the car, and what an M3U or PLS '
              'export writes out.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    AppProvider provider,
    Playlist playlist,
  ) {
    final stations = provider.stationsOf(playlist);
    final n = stations.length;

    return ExpansionTile(
      leading: const Icon(Icons.queue_music),
      title: Text(playlist.name),
      subtitle: Text('$n station${n == 1 ? '' : 's'}'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => switch (value) {
          'play' => _playAll(context, provider, stations),
          'rename' => _rename(context, provider, playlist),
          _ => _confirmDelete(context, provider, playlist),
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'play',
            enabled: n > 0,
            child: const Text('Play playlist'),
          ),
          const PopupMenuItem(value: 'rename', child: Text('Rename…')),
          const PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
        ],
      ),
      children: [
        if (stations.isEmpty)
          const ListTile(
            dense: true,
            title: Text(
              'Empty. Add stations from the Stations screen, using the menu '
              'at the end of a station row.',
            ),
          )
        else
          for (final s in stations)
            StationTile(
              station: s,
              onTap: () => _play(context, provider, s, stations),
              trailing: MarkdownTooltip(
                message: '''

                **Remove from playlist**

                Take this station out of ${playlist.name}. It stays in your
                library and in any other playlist it belongs to.

                ''',
                child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () =>
                      provider.removeFromPlaylist(playlist.id, s.id),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _create(BuildContext context, AppProvider provider) async {
    final name = await showPlaylistNameDialog(context, title: 'New playlist');
    if (name == null || !context.mounted) return;

    await provider.addPlaylist(name);
    if (!context.mounted) return;
    showPositiveSnackBar(context, 'Created $name.');
  }

  Future<void> _rename(
    BuildContext context,
    AppProvider provider,
    Playlist playlist,
  ) async {
    final name = await showPlaylistNameDialog(
      context,
      title: 'Rename playlist',
      initial: playlist.name,
    );
    if (name == null || !context.mounted) return;

    await provider.renamePlaylist(playlist.id, name);
  }

  /// Delete a playlist. The stations in it stay in the library, which is what
  /// the confirmation says so nobody hesitates over losing them.

  Future<void> _confirmDelete(
    BuildContext context,
    AppProvider provider,
    Playlist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          '${playlist.name} will be deleted. The stations in it stay in your '
          'library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await provider.deletePlaylist(playlist.id);
    if (!context.mounted) return;
    showPositiveSnackBar(context, 'Deleted ${playlist.name}.');
  }

  void _playAll(
    BuildContext context,
    AppProvider provider,
    List<Station> stations,
  ) {
    if (stations.isEmpty) return;
    _play(context, provider, stations.first, stations);
  }

  Future<void> _play(
    BuildContext context,
    AppProvider provider,
    Station station,
    List<Station> queue,
  ) async {
    try {
      await provider.play(station, queue: queue);
    } catch (e) {
      if (!context.mounted) return;
      await showErrorDialog(
        context,
        title: 'Cannot play ${station.name}',
        message: 'The stream could not be reached.\n\n$e',
      );
    }
  }
}
