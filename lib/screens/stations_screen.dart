/// StationsScreen — the saved station library.
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

import 'package:audio_service/audio_service.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/stations_widgets/add_to_playlist_sheet.dart';
import 'package:radiopod/screens/stations_widgets/station_empty_state.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';
import 'package:radiopod/widgets/startup_overlay.dart';
import 'package:radiopod/widgets/station_tile.dart';

/// Every saved station, alphabetically, with a filter box for long libraries.
///
/// Tapping a station starts it with the whole visible list as its queue, so
/// Next and Previous walk the same list the user is looking at.

class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key});

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final query = _filter.text.trim().toLowerCase();
    final visible = [
      for (final s in provider.stationsByName)
        if (query.isEmpty || s.name.toLowerCase().contains(query)) s,
    ];

    return StartupOverlay(
      phase: provider.startupPhase,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _filter,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.filter_list),
                hintText: 'Filter your stations',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _filter.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_filter.clear),
                      ),
              ),
            ),
          ),
          Expanded(
            child: provider.busy
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? StationEmptyState(filtered: query.isNotEmpty)
                : _list(provider, visible),
          ),
        ],
      ),
    );
  }

  /// The station list, rebuilt as the media session changes so the station
  /// currently on air is highlighted wherever it was started from.

  Widget _list(AppProvider provider, List<Station> visible) {
    return StreamBuilder<MediaItem?>(
      stream: Player.handler.mediaItem,
      builder: (context, snapshot) {
        final playingId = snapshot.data?.extras?['stationId'] as String?;

        return ListView.builder(
          itemCount: visible.length,
          itemBuilder: (context, i) {
            final station = visible[i];

            return StationTile(
              station: station,
              selected: station.id == playingId,
              onTap: () => _play(provider, station, visible),
              trailing: _menu(provider, station),
            );
          },
        );
      },
    );
  }

  Widget _menu(AppProvider provider, Station station) => MarkdownTooltip(
    message: '''

    **Station actions**

    Add this station to one of your playlists, or remove it from your
    library altogether.

    ''',
    child: PopupMenuButton<String>(
      onSelected: (value) => value == 'playlists'
          ? _choosePlaylists(station)
          : _confirmDelete(provider, station),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'playlists', child: Text('Add to playlist…')),
        PopupMenuItem(value: 'delete', child: Text('Delete station')),
      ],
    ),
  );

  Future<void> _play(
    AppProvider provider,
    Station station,
    List<Station> queue,
  ) async {
    try {
      await provider.play(station, queue: queue);
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: 'Cannot play ${station.name}',
        message:
            'The stream could not be reached.\n\n'
            'Radio stations change and retire their stream addresses, so a '
            'station saved a while ago may simply be gone. Try finding it '
            'again in Search.\n\n$e',
      );
    }
  }

  Future<void> _choosePlaylists(Station station) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AddToPlaylistSheet(station: station),
  );

  /// Confirm before deleting, because a deleted station also disappears from
  /// every playlist that referenced it.

  Future<void> _confirmDelete(AppProvider provider, Station station) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete station?'),
        content: Text(
          '${station.name} will be removed from your library and from every '
          'playlist it appears in.',
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
    if (confirmed != true || !mounted) return;

    await provider.deleteStation(station.id);
    if (!mounted) return;
    showPositiveSnackBar(context, 'Deleted ${station.name}.');
  }
}
