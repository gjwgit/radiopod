/// AddToPlaylistSheet — pick the playlists a station belongs to.
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

import 'package:provider/provider.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';

/// A bottom sheet of checkboxes, one per playlist, for [station].
///
/// Ticking and unticking writes straight through to the provider rather than
/// batching up an Apply button: each change is a single small Pod write, and
/// the sheet stays open so several playlists can be set in one visit.

class AddToPlaylistSheet extends StatelessWidget {
  final Station station;

  const AddToPlaylistSheet({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final playlists = provider.playlists;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Playlists for ${station.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Text(
                'You have no playlists yet. Create one on the Playlists '
                'screen and it will appear here.',
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in playlists)
                    CheckboxListTile(
                      title: Text(p.name),
                      value: p.stationIds.contains(station.id),
                      onChanged: (checked) => checked ?? false
                          ? provider.addToPlaylist(p.id, station.id)
                          : provider.removeFromPlaylist(p.id, station.id),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
