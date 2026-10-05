/// PlaylistsScreen — create and edit named groups of stations.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
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
import 'package:provider/provider.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/playlists_widgets/playlist_name_dialog.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';
import 'package:radiopod/widgets/now_playing.dart';
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
            : NowPlayingBuilder(
                // 20261005 gjw The playlists themselves reorder too, which
                // is a different thing from the order of stations inside
                // one. This is the order the driver scrolls past in the car
                // before reaching All Stations.
                //
                // A reorderable list inside a reorderable list. Each handle
                // binds to its NEAREST reorderable ancestor, so the grips on
                // the station rows drive the inner list and the grip on a
                // playlist header drives this one. Both set
                // buildDefaultDragHandles: false, without which a long press
                // anywhere would start a drag in whichever list caught it.

                builder: (context, now) => ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  buildDefaultDragHandles: false,
                  itemCount: provider.playlists.length,
                  onReorderItem: provider.reorderPlaylist,
                  itemBuilder: (context, i) =>
                      _tile(context, provider, provider.playlists[i], now, i),
                ),
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
    NowPlaying now,
    int index,
  ) {
    final stations = provider.stationsOf(playlist);
    final n = stations.length;

    return ExpansionTile(
      // Keyed by playlist id: stable across a reorder, where the index is
      // not, and required by ReorderableListView.

      key: ValueKey(playlist.id),
      leading: const Icon(Icons.queue_music),
      title: Text(playlist.name),
      subtitle: Text('$n station${n == 1 ? '' : 's'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
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
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete playlist'),
              ),
            ],
          ),

          // No tooltip, for the reason given on the Stations screen: a
          // tooltip is an OverlayPortal and reordering re-parents the
          // dragged row, which asserts mid-drag.
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
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
          // 20261005 gjw Reorderable, so a playlist can be put in the order
          // the driver wants to hear it. shrinkWrap and
          // NeverScrollableScrollPhysics because this sits inside the
          // ExpansionTile of an outer scrolling list: without them the inner
          // list claims unbounded height and fights the outer one for the
          // drag gesture.
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),

            // Handles are supplied explicitly, as on the Stations screen, so
            // the rest of the row keeps its tap-to-play behaviour; the
            // default handles start a drag on a long press anywhere.
            buildDefaultDragHandles: false,
            itemCount: stations.length,
            onReorderItem: (oldIndex, newIndex) =>
                provider.reorderInPlaylist(playlist.id, oldIndex, newIndex),
            itemBuilder: (context, i) => _playlistRow(
              context,
              provider,
              playlist,
              stations[i],
              stations,
              now,
              i,
            ),
          ),
      ],
    );
  }

  /// One station row inside a playlist.
  ///
  /// Keyed by station id, which ReorderableListView requires and which must
  /// be stable across the reorder — the index is not.

  Widget _playlistRow(
    BuildContext context,
    AppProvider provider,
    Playlist playlist,
    Station s,
    List<Station> stations,
    NowPlaying now,
    int index,
  ) => StationTile(
    key: ValueKey('${playlist.id}:${s.id}'),
    station: s,
    current: now.isCurrent(s.id),
    playing: now.playing,
    connecting: now.connecting,
    loading: now.loading,
    paused: now.paused,
    failed: now.failed,
    track: now.track,
    onTap: () => now.isCurrent(s.id)
        ? _toggle(now)
        : _play(context, provider, s, stations),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownTooltip(
          message:
              '''

          **Remove from playlist**

          Take this station out of ${playlist.name}. It stays in your
          library and in any other playlist it belongs to.

          ''',
          child: IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => provider.removeFromPlaylist(playlist.id, s.id),
          ),
        ),

        // DELIBERATELY WITHOUT A TOOLTIP, for the reason given on the
        // Stations screen: a tooltip is an OverlayPortal and reordering
        // re-parents the dragged row, which asserts mid-drag.
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.drag_handle),
          ),
        ),
      ],
    ),
  );

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

  /// Stop the station on air, or start it again where it left off.

  Future<void> _toggle(NowPlaying now) =>
      now.playing ? Player.handler.stop() : Player.handler.play();

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
