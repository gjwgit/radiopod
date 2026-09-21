/// SettingsScreen — privacy explanation and the device-local cache.
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

import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/library_cache.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';

/// Says plainly where RadioPod's data goes, and offers the one lever the user
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
          Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
          const Gap(8),
          _paragraph(
            cs,
            'Your stations and playlists are written to your own Solid Pod, '
            'encrypted with your security key before they leave this device. '
            'The server holding them — including its administrators — cannot '
            'read which stations you keep.',
          ),
          const Gap(12),
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
            'Playing a station connects directly to that station\'s stream, '
            'so the broadcaster sees a connection from your network, exactly '
            'as it would from any radio player or web browser. RadioPod adds '
            'nothing to that request.',
          ),

          const Gap(32),
          Text(
            'Offline station cache',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Gap(8),
          _paragraph(
            cs,
            'Android Auto starts RadioPod on its own, often before you have '
            'opened the app or unlocked your Pod, and it will not wait while '
            'a login completes. So a copy of your station names and stream '
            'addresses is kept on this device, in the app\'s private storage, '
            'for the car to browse.',
          ),
          const Gap(12),
          _paragraph(
            cs,
            'Unlike the copy on your Pod, this one is not encrypted. It holds '
            'no more than a playlist file would — names and stream addresses, '
            'never your security key or WebID — and it never leaves the '
            'device. Clearing it costs you only the ability to browse your '
            'stations in the car before opening the app; it is rebuilt the '
            'next time your library loads.',
          ),
          const Gap(16),
          MarkdownTooltip(
            message: '''

            **Clear cache**

            Forget the unencrypted copy of your station names and stream
            addresses held on this device for Android Auto. Your Pod is not
            touched, and the cache is rebuilt the next time your library
            loads.

            ''',
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear offline cache'),
              onPressed: () => _clearCache(context),
            ),
          ),

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

  Future<void> _clearCache(BuildContext context) async {
    await LibraryCache.clear();
    if (!context.mounted) return;
    showPositiveSnackBar(context, 'Offline station cache cleared.');
  }
}
