/// SearchResultDialog — what is known about a search result, before saving.
///
// Time-stamp: <Sunday 2026-10-18 06:00:00 +1100 Graham Williams>
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

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/stations_widgets/station_details.dart';
import 'package:radiopod/services/podcast_index.dart';

/// Show what is known about [station], read-only, with Save offered unless
/// it is [saved] already.
///
/// 20261018 gjw Properties shows the same details, but only for a station
/// already saved. This answers "what is this?" before deciding to save it.
/// A podcast adds its description and episode count from Podcast Index
/// ([podcastAbout]), which a saved podcast does not keep.

Future<void> showSearchResultDialog(
  BuildContext context,
  Station station, {
  required bool saved,
  required VoidCallback onSave,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _SearchResultDialog(station: station, saved: saved, onSave: onSave),
  );
}

class _SearchResultDialog extends StatelessWidget {
  final Station station;
  final bool saved;
  final VoidCallback onSave;

  const _SearchResultDialog({
    required this.station,
    required this.saved,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final about = podcastAbout[station];
    final description = about?.description;
    final episodes = about?.episodes;
    final subtitle = [
      station.subtitle,
      if (episodes != null) '$episodes episode${episodes == 1 ? '' : 's'}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return AlertDialog(
      title: Row(
        children: [
          _logo(cs),
          const Gap(16),
          Expanded(child: Text(station.name)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (description != null) ...[
                const Gap(16),
                SelectableText(description, style: text.bodyMedium),
              ],
              StationDetails(station: station),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          icon: Icon(saved ? Icons.check : Icons.add_circle_outline),
          label: Text(saved ? 'Saved' : 'Save'),
          onPressed: saved
              ? null
              : () {
                  Navigator.of(context).pop();
                  onSave();
                },
        ),
      ],
    );
  }

  /// The result's logo, from the network as the search row's is: browsing
  /// results is not listening, and they are not kept (StationLogoCache).

  Widget _logo(ColorScheme cs) {
    final fallback = Icon(
      station.isPodcast ? Icons.podcasts : Icons.radio,
      color: cs.primary,
      size: 40,
    );
    final favicon = station.favicon;
    if (favicon == null || favicon.isEmpty) return fallback;

    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          favicon,
          fit: BoxFit.cover,
          // See station_tile.dart for why the web needs this.
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
