/// SettingsScreen — where your data lives, and the privacy explanation.
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
import 'package:provider/provider.dart';

import 'package:radiopod/screens/settings_widgets/library_storage_section.dart';
import 'package:radiopod/services/app_provider.dart';

/// Says plainly where RadioPod's data goes, and offers the levers the user
/// has over it.
///
/// A privacy page that only makes claims is worth little, so this one names
/// the exact endpoint that is contacted, what is sent, and what is
/// deliberately not sent. Window size, theme and the security key live in the
/// profile menu that solidui provides, not here.

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Where the library lives ─────────────────────────────────

          const LibraryStorageSection(),

          // ── Privacy ─────────────────────────────────────────────────
          const Gap(32),
          Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
          const Gap(8),
          _paragraph(
            cs,
            'RadioPod contacts exactly one third party, and only when you '
            'use Search: the community-run Radio-Browser database at '
            'all.api.radio-browser.info. It is sent your search text and the '
            'name of this app, and nothing else — no WebID, no Pod address, '
            'no station library.',
          ),
          const Gap(12),
          _paragraph(
            cs,
            'Radio-Browser offers an endpoint for apps to report which '
            'station a listener picked, which feeds its popularity ranking. '
            'RadioPod does not call it. Nothing about what you listen to '
            'leaves this device.',
          ),
          const Gap(12),
          _paragraph(
            cs,
            "Playing a station connects directly to that station's stream, "
            'so the broadcaster sees a connection from your network, exactly '
            'as it would from any radio player or web browser. RadioPod adds '
            'nothing to that request.',
          ),

          // ── Library size ────────────────────────────────────────────
          const Gap(32),
          Text('Your library', style: Theme.of(context).textTheme.titleLarge),
          const Gap(8),
          _paragraph(
            cs,
            '${provider.stations.length} stations in '
            '${provider.playlists.length} playlists.',
          ),
        ],
      ),
    );
  }

  Widget _paragraph(ColorScheme cs, String text) =>
      Text(text, style: TextStyle(color: cs.onSurfaceVariant));
}
