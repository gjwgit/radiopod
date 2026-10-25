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
import 'package:radiopod/screens/playlists_widgets/playlists_bar.dart';
import 'package:radiopod/screens/podcast_screen.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/utils/station_filter.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';
import 'package:radiopod/widgets/now_playing.dart';
import 'package:radiopod/widgets/now_playing_stop_button.dart';
import 'package:radiopod/widgets/startup_overlay.dart';
import 'package:radiopod/widgets/station_tile.dart';
import 'package:radiopod/widgets/swipe_to_remove.dart';

/// Playlists, each expanding to show the stations it holds.
///
/// Playlists matter beyond tidiness: they are the folders Android Auto shows
/// in the car, and the unit an M3U or PLS file exports to. Stations go into
/// playlists through Manage playlists, a grid of every station against
/// every playlist.
///
/// 20261025 gjw The filter keeps a playlist whose name matches, or that
/// holds a matching station, and then shows only those stations. Dragging
/// is offered only with the filter empty, as on Stations: a position in a
/// filtered list says nothing about where the hidden rows sit.

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  String get _query => _filter.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Each playlist shown, with the stations the filter keeps in it.

    final shown = [
      for (final p in provider.playlists)
        if (playlistMatches(
              p.name,
              provider.stationsOf(p),
              provider.castsOf,
              _query,
            )
            case final stations?)
          (playlist: p, stations: stations),
    ];

    return StartupOverlay(
      phase: provider.startupPhase,
      child: Scaffold(
        // Blank while starting up: StartupOverlay already covers this with
        // its own spinner and the scrim is translucent. See the longer note
        // in stations_screen.dart.
        body: provider.isStartingUp
            ? const SizedBox.shrink()
            : Column(
                children: [
                  PlaylistsBar(
                    controller: _filter,
                    onChanged: () => setState(() {}),
                    canManage:
                        provider.playlists.isNotEmpty &&
                        provider.stations.isNotEmpty,
                    trailing: NowPlayingStopButton(
                      stations: provider.stations,
                      first: provider.firstPlaylistPodcastToPlay?.podcast,
                      onFirst: (s) => _play(
                        context,
                        provider,
                        s,
                        provider.firstPlaylistPodcastToPlay?.queue ?? [s],
                      ),
                    ),
                  ),
                  Expanded(child: _body(context, provider, shown)),
                ],
              ),
        floatingActionButton: MarkdownTooltip(
          message: '''

          **New playlist**

          Create an empty playlist, then fill it with Manage playlists.
          Playlists are what Android Auto lists in the car.

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

  Widget _body(
    BuildContext context,
    AppProvider provider,
    List<({Playlist playlist, List<Station> stations})> shown,
  ) => provider.busy
      ? const Center(child: CircularProgressIndicator())
      : provider.playlists.isEmpty
      ? _empty(context)
      : shown.isEmpty
      ? const Center(child: Text('No playlist matches the filter.'))
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
            itemCount: shown.length,
            onReorderItem: provider.reorderPlaylist,
            itemBuilder: (context, i) => _tile(
              context,
              provider,
              shown[i].playlist,
              shown[i].stations,
              now,
              i,
            ),
          ),
        );

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
    List<Station> stations,
    NowPlaying now,
    int index,
  ) {
    final queue = provider.stationsOf(playlist);
    final n = queue.length;

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
          MarkdownTooltip(
            message: '''

            **Playlist actions**

            Play this playlist from the top, rename it, or delete it. The
            stations in it stay in your library.

            ''',
            // An empty tooltip turns off the menu's own plain "Show menu".
            child: PopupMenuButton<String>(
              tooltip: '',
              onSelected: (value) => switch (value) {
                'play' => _playAll(context, provider, queue),
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
          ),

          // No tooltip, for the reason given on the Stations screen: a
          // tooltip is an OverlayPortal and reordering re-parents the
          // dragged row, which asserts mid-drag.
          if (_query.isEmpty)
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
            title: Text('Empty. Add stations with Manage playlists, above.'),
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
  ) => SwipeToRemove(
    key: ValueKey('${playlist.id}:${s.id}'),
    onRemove: () => provider.removeFromPlaylist(playlist.id, s.id),
    child: _playlistTile(context, provider, playlist, s, stations, now, index),
  );

  /// The tile inside [_playlistRow], which a swipe left removes from the
  /// playlist without asking: the station stays in the library.

  Widget _playlistTile(
    BuildContext context,
    AppProvider provider,
    Playlist playlist,
    Station s,
    List<Station> stations,
    NowPlaying now,
    int index,
  ) => StationTile(
    station: s,
    current: now.isCurrent(s.id),
    playing: now.playing,
    connecting: now.connecting,
    loading: now.loading,
    paused: now.paused,
    failed: now.failed,
    track: now.track,
    details: s.isPodcast
        ? podcastDetails(
            s,
            toPlay: provider.castsToPlay(s.id),
            total: provider.castsOf(s.id).length,
          )
        : null,
    onTap: () => now.isCurrent(s.id)
        ? _toggle(now)
        : _play(context, provider, s, stations),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 20261026 gjw The Episodes button, as on Stations, where a Remove
        // button was: a swipe left still takes a station out. A radio row
        // keeps the space, so the drag handles stay in line.
        if (s.isPodcast)
          MarkdownTooltip(
            message: '''

            **Episodes**

            What this podcast is about, and its episodes: what each is
            about, how long it runs and how far you got. Skip any you never
            want to hear.

            ''',
            child: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PodcastScreen(
                    podcastId: s.id,
                    initialFilter: _filter.text,
                  ),
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 48),

        // DELIBERATELY WITHOUT A TOOLTIP, for the reason given on the
        // Stations screen: a tooltip is an OverlayPortal and reordering
        // re-parents the dragged row, which asserts mid-drag.
        if (_query.isEmpty)
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
      await showPlayError(
        context,
        station: station,
        error: e,
        otherwise: station.isPodcast
            ? 'The episode could not be fetched from the podcast\'s server.'
            : 'The stream could not be reached.',
      );
    }
  }
}
