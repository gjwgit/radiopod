/// StationsScreen — the saved station library.
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

import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';
// Only the breakpoint. A bare solidui import would collide with this file's
// own showPositiveSnackBar.
import 'package:solidui/solidui.dart' show NavigationConstants;

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/stations_widgets/add_to_playlist_sheet.dart';
import 'package:radiopod/screens/stations_widgets/station_empty_state.dart';
import 'package:radiopod/screens/stations_widgets/station_properties_dialog.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';
import 'package:radiopod/widgets/now_playing.dart';
import 'package:radiopod/widgets/startup_overlay.dart';
import 'package:radiopod/widgets/station_tile.dart';

/// Every saved station, in the order the user put them in, with a filter box
/// for long libraries.
///
/// The list is NOT alphabetical. Stations are shown in library order and can
/// be dragged into any order the user likes; that order is saved and is what
/// the car and an export see too. Dragging is offered only when the filter
/// box is empty — see [_list] for why.
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
      for (final s in provider.stations)
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
            // 20261007 gjw NOTHING HERE WHILE STARTING UP. StartupOverlay is
            // already drawing a spinner and a message over this, and its
            // scrim is translucent, so a second indicator showed through it
            // — lower on screen, because this one centres below the filter
            // box. That was the double animation on launch.
            //
            // Blank rather than the empty state: "No stations yet" glowing
            // through the scrim would be worse than the extra spinner, and
            // is exactly what AppProvider.busy folds isStartingUp in to
            // prevent.
            child: provider.isStartingUp
                ? const SizedBox.shrink()
                : provider.busy
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? StationEmptyState(filtered: query.isNotEmpty)
                : _list(provider, visible, reorderable: query.isEmpty),
          ),
        ],
      ),
    );
  }

  /// The station list, rebuilt as the media session changes so the station
  /// currently on air is highlighted wherever it was started from.
  ///
  /// Dragging is offered only when [reorderable] — that is, when the filter
  /// box is empty. A filtered list shows some stations and hides others, so
  /// a position in it does not say where the station belongs in the library:
  /// dropping between two visible rows would be ambiguous about every hidden
  /// station in the gap. Rather than guess and silently scramble the order,
  /// the handles simply are not there while filtering, and the Stations menu
  /// tooltip says so.

  Widget _list(
    AppProvider provider,
    List<Station> visible, {
    required bool reorderable,
  }) {
    return NowPlayingBuilder(
      builder: (context, now) {
        Widget row(int i) {
          final station = visible[i];
          final current = now.isCurrent(station.id);

          return StationTile(
            key: ValueKey(station.id),
            station: station,
            current: current,
            playing: now.playing,
            connecting: now.connecting,
            loading: now.loading,
            paused: now.paused,
            failed: now.failed,
            track: now.track,

            // Tapping the station on air toggles it; tapping any other row
            // switches to that station.
            onTap: () =>
                current ? _toggle(now) : _play(provider, station, visible),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actions(provider, station),
                if (reorderable) _dragHandle(i),
              ],
            ),
          );
        }

        if (!reorderable) {
          return ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, i) => row(i),
          );
        }

        return ReorderableListView.builder(
          // 20260922 gjw Handles are supplied explicitly below rather than
          // by the list, so that the rest of the row keeps its normal tap
          // behaviour: with the default handles a long press anywhere on
          // mobile starts a drag, which fights with tapping to play.
          buildDefaultDragHandles: false,
          itemCount: visible.length,
          itemBuilder: (context, i) => row(i),
          onReorderItem: (oldIndex, newIndex) =>
              provider.reorderStation(oldIndex, newIndex),
        );
      },
    );
  }

  /// The grip used to drag a row.
  ///
  /// DELIBERATELY WITHOUT A TOOLTIP. A tooltip is an OverlayPortal, and
  /// reordering re-parents the dragged row; reactivating a portal that is
  /// currently showing asserts with "A _RenderLayoutBuilder was mutated in
  /// _RenderLayoutBuilder.performLayout". The handle is the widget under the
  /// pointer for the whole drag, so its tooltip is the live one. Wrapping it
  /// conditionally is worse still — changing a reorderable row's widget
  /// structure mid-drag unmounts the element and silently cancels the drag.
  /// Drag-to-reorder is documented in the Stations menu tooltip instead.

  Widget _dragHandle(int index) => ReorderableDragStartListener(
    index: index,
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.drag_handle),
    ),
  );

  /// The row's actions: three buttons where there is room, else one menu.
  ///
  /// 20261008 gjw Measured against the SCREEN rather than the row, and
  /// against solidui's own narrow/wide threshold, so the row changes at the
  /// same width as the navigation does. Two breakpoints a hundred pixels
  /// apart would read as a glitch while a window is dragged.
  ///
  /// The actions themselves are identical either way, and so are their
  /// tooltips — only the number of taps to reach them differs.

  Widget _actions(AppProvider provider, Station station) =>
      rowShowsButtons(MediaQuery.sizeOf(context).width)
      ? _buttons(provider, station)
      : _menu(provider, station);

  /// The same three actions, each on its own button.

  Widget _buttons(AppProvider provider, Station station) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _button(
        icon: Icons.tune,
        tooltip: '''

        **Properties**

        Rename this station, give it an icon, and say what should happen
        when its stream ends.

        ''',
        onPressed: () => _editProperties(provider, station),
      ),
      _button(
        icon: Icons.playlist_add,
        tooltip: '''

        **Add to playlist**

        Put this station into one or more of your playlists. A station lives
        once and is referenced from each playlist, so renaming it later
        updates them all.

        ''',
        onPressed: () => _choosePlaylists(station),
      ),
      _button(
        icon: Icons.delete_outline,
        tooltip: '''

        **Delete station**

        Remove this station from your library and from every playlist it
        appears in. You will be asked to confirm.

        ''',
        onPressed: () => _confirmDelete(provider, station),
      ),
    ],
  );

  /// One action button, sized so three of them fit where the menu was.
  ///
  /// visualDensity is tightened because the default IconButton is 48 wide:
  /// three at that size push a long station name into an ellipsis on the
  /// very screens that were supposed to have more room.

  Widget _button({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) => MarkdownTooltip(
    message: tooltip,
    child: IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    ),
  );

  Widget _menu(AppProvider provider, Station station) => MarkdownTooltip(
    message: '''

    **Station actions**

    Rename this station, give it an icon, say what should happen when its
    stream ends, add it to a playlist, or remove it from your library.

    ''',
    child: PopupMenuButton<String>(
      onSelected: (value) => switch (value) {
        'properties' => _editProperties(provider, station),
        'playlists' => _choosePlaylists(station),
        _ => _confirmDelete(provider, station),
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'properties', child: Text('Properties…')),
        PopupMenuItem(value: 'playlists', child: Text('Add to playlist…')),
        PopupMenuItem(value: 'delete', child: Text('Delete station')),
      ],
    ),
  );

  /// Stop the station on air, or start it again where it left off.

  Future<void> _toggle(NowPlaying now) =>
      now.playing ? Player.handler.stop() : Player.handler.play();

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

  /// Rename the station, set its icon, and choose what a stream end means.

  Future<void> _editProperties(AppProvider provider, Station station) async {
    final updated = await showStationPropertiesDialog(context, station);
    if (updated == null || !mounted) return;

    await provider.updateStation(updated);
    if (!mounted) return;
    showPositiveSnackBar(context, 'Updated ${updated.name}.');
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

/// Whether a station row has room to show its actions as separate buttons.
///
/// 20261008 gjw Pure, and tested, because the alternative is not testable at
/// all: pumping StationsScreen needs a live Player, so a widget test cannot
/// reach this decision.
///
/// The threshold is solidui's own narrow/wide one rather than a number
/// chosen here, so the row's actions change at the same width as the
/// navigation does. Two breakpoints a hundred pixels apart would read as a
/// glitch while a window is being dragged, and this way the app has one
/// answer to "is this a narrow screen".

bool rowShowsButtons(double screenWidth) =>
    screenWidth >= NavigationConstants.narrowScreenThreshold;
