/// ManagePlaylistsDialog — every station against every playlist, to tick.
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

import 'dart:math';

import 'package:flutter/gestures.dart';

import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/utils/station_filter.dart';

/// Show the grid, its filter starting with [filter].

Future<void> showManagePlaylists(BuildContext context, {String filter = ''}) =>
    showDialog<void>(
      context: context,
      builder: (_) => ManagePlaylistsDialog(initialFilter: filter),
    );

/// A grid with a row per station, radio or podcast, and a column per
/// playlist; a tick puts the station in the playlist.
///
/// 20261025 gjw Replaces Add to playlist on each Stations row, which set one
/// station's playlists at a time. Here a new playlist is filled, or the
/// library sorted into playlists, in one pass down the list. Each tick
/// writes through at once, as the old sheet did, so there is no Apply to
/// forget.

class ManagePlaylistsDialog extends StatefulWidget {
  const ManagePlaylistsDialog({super.key, this.initialFilter = ''});

  final String initialFilter;

  @override
  State<ManagePlaylistsDialog> createState() => _ManagePlaylistsDialogState();
}

class _ManagePlaylistsDialogState extends State<ManagePlaylistsDialog> {
  late final _filter = TextEditingController(text: widget.initialFilter);

  // 20261116 gjw The station names and the ticks are two lists, so the names
  // can stay put while the ticks scroll sideways. Each follows the other up
  // and down.

  final _names = ScrollController();
  final _ticks = ScrollController();
  final _across = ScrollController();

  static const _column = 76.0;
  static const _header = 48.0;
  static const _rowHeight = 48.0;

  // Room below the lists for the sideways scrollbar, so it does not cover
  // the last row. Both lists keep it, to stay the same height.

  static const _bar = 14.0;

  @override
  void initState() {
    super.initState();
    _names.addListener(() => _follow(_names, _ticks));
    _ticks.addListener(() => _follow(_ticks, _names));
  }

  @override
  void dispose() {
    _filter.dispose();
    _names.dispose();
    _ticks.dispose();
    _across.dispose();
    super.dispose();
  }

  void _follow(ScrollController from, ScrollController to) {
    if (to.hasClients && to.offset != from.offset) to.jumpTo(from.offset);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final playlists = provider.playlists;
    final query = _filter.text.trim().toLowerCase();
    final stations = [
      for (final s in provider.stations)
        if (stationMatches(s, provider.castsOf(s.id), query)) s,
    ];

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            children: [
              Text(
                'Manage playlists',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _filterField(),
              const SizedBox(height: 8),
              Expanded(
                child: playlists.isEmpty
                    ? const Center(
                        child: Text(
                          'You have no playlists yet. Create one with New '
                          'playlist and it will appear here as a column.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : stations.isEmpty
                    ? const Center(child: Text('No station matches.'))
                    : _grid(provider, playlists, stations),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterField() => TextField(
    controller: _filter,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.filter_list),
      hintText: 'Filter the stations.',
      border: const OutlineInputBorder(),
      isDense: true,
      suffixIcon: _filter.text.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(_filter.clear),
            ),
    ),
  );

  /// The header of playlist names stays put while the stations scroll
  /// under it. With more playlists than fit, the playlists scroll sideways
  /// and the station names stay put beside them.

  Widget _grid(
    AppProvider provider,
    List<Playlist> playlists,
    List<Station> stations,
  ) => LayoutBuilder(
    builder: (context, box) {
      final name = box.maxWidth < 500 ? 140.0 : 260.0;
      final width = max(box.maxWidth - name, playlists.length * _column);
      final quiet = ScrollConfiguration.of(context).copyWith(scrollbars: false);

      return Row(
        children: [
          SizedBox(
            width: name,
            child: Column(
              children: [
                const SizedBox(height: _header),
                const Divider(height: 1),
                Expanded(
                  // One scrollbar is enough, and it belongs to the ticks.
                  child: ScrollConfiguration(
                    behavior: quiet,
                    child: ListView.builder(
                      controller: _names,
                      itemExtent: _rowHeight,
                      itemCount: stations.length,
                      itemBuilder: (context, i) => _name(stations[i]),
                    ),
                  ),
                ),
                const SizedBox(height: _bar),
              ],
            ),
          ),
          Expanded(
            child: _playlistColumns(
              provider,
              playlists,
              stations,
              width,
              box.maxHeight,
              quiet,
            ),
          ),
        ],
      );
    },
  );

  /// The playlist columns, scrolled sideways under their headings.
  ///
  /// 20261116 gjw On desktop a mouse does not drag a scroll view and the
  /// scrollbar only shows while scrolling, so columns past the edge could
  /// not be reached at all. The sideways scrollbar is now always shown and a
  /// mouse can drag the columns. The up and down scrollbar is drawn here,
  /// at the visible edge, rather than by the list, whose own right edge is
  /// off screen when there are many playlists.

  Widget _playlistColumns(
    AppProvider provider,
    List<Playlist> playlists,
    List<Station> stations,
    double width,
    double height,
    ScrollBehavior quiet,
  ) => Scrollbar(
    controller: _ticks,
    notificationPredicate: (n) =>
        n.depth == 1 && n.metrics.axis == Axis.vertical,
    child: Scrollbar(
      controller: _across,
      thumbVisibility: true,
      child: ScrollConfiguration(
        behavior: quiet.copyWith(
          dragDevices: {...quiet.dragDevices, PointerDeviceKind.mouse},
        ),
        child: SingleChildScrollView(
          controller: _across,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              children: [
                Row(children: [for (final p in playlists) _heading(p)]),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: _ticks,
                    itemExtent: _rowHeight,
                    itemCount: stations.length,
                    itemBuilder: (context, i) =>
                        _row(provider, playlists, stations[i]),
                  ),
                ),
                const SizedBox(height: _bar),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _heading(Playlist p) => MarkdownTooltip(
    message:
        '''

    **${p.name}**

    Tick a station to put it in this playlist, untick it to take it out.
    The station stays in your library either way.

    ''',
    child: Container(
      width: _column,
      height: _header,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        p.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    ),
  );

  Widget _name(Station s) => Row(
    children: [
      Icon(s.isPodcast ? Icons.podcasts : Icons.radio, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
    ],
  );

  Widget _row(AppProvider provider, List<Playlist> playlists, Station s) => Row(
    children: [
      for (final p in playlists)
        SizedBox(
          width: _column,
          child: Checkbox(
            value: p.stationIds.contains(s.id),
            semanticLabel: '${s.name} in ${p.name}',
            onChanged: (on) => on ?? false
                ? provider.addToPlaylist(p.id, s.id)
                : provider.removeFromPlaylist(p.id, s.id),
          ),
        ),
    ],
  );
}
