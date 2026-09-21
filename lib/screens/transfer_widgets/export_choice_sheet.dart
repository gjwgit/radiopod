/// ExportChoiceSheet — choose what to export and in which format.
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

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/playlist_file.dart';

/// What an export chose: the stations, a name for the file, and the format.

typedef ExportChoice = ({
  List<Station> stations,
  String name,
  PlaylistFormat format,
});

/// A bottom sheet listing the whole library and every playlist, with a format
/// toggle above them.
///
/// The format sits at the top and the target below because the format is a
/// one-off decision the user rarely changes, while the list is what they came
/// to pick. Tapping a row both chooses it and closes the sheet — there is no
/// separate Export button to hunt for.

class ExportChoiceSheet extends StatefulWidget {
  final List<Station> allStations;
  final List<Playlist> playlists;
  final List<Station> Function(Playlist) stationsOf;

  const ExportChoiceSheet({
    super.key,
    required this.allStations,
    required this.playlists,
    required this.stationsOf,
  });

  @override
  State<ExportChoiceSheet> createState() => _ExportChoiceSheetState();
}

class _ExportChoiceSheetState extends State<ExportChoiceSheet> {
  PlaylistFormat _format = PlaylistFormat.m3u;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Column(
              children: [
                Text(
                  'Export a playlist',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Gap(12),
                SegmentedButton<PlaylistFormat>(
                  segments: [
                    for (final f in PlaylistFormat.values)
                      ButtonSegment(value: f, label: Text(f.label)),
                  ],
                  selected: {_format},
                  onSelectionChanged: (s) =>
                      setState(() => _format = s.first),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _row(
                  context,
                  icon: Icons.radio,
                  name: appName,
                  label: 'All stations',
                  stations: widget.allStations,
                ),
                const Divider(height: 1),
                for (final p in widget.playlists)
                  _row(
                    context,
                    icon: Icons.queue_music,
                    name: p.name,
                    label: p.name,
                    stations: widget.stationsOf(p),
                  ),
              ],
            ),
          ),
          const Gap(8),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String name,
    required String label,
    required List<Station> stations,
  }) {
    final n = stations.length;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text('$n station${n == 1 ? '' : 's'}'),
      enabled: n > 0,
      onTap: () => Navigator.of(context).pop<ExportChoice>((
        stations: stations,
        name: name,
        format: _format,
      )),
    );
  }
}
