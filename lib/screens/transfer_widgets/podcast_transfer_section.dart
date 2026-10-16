/// PodcastTransferSection — podcasts in and out of RadioPod as OPML.
///
// Time-stamp: <Friday 2026-10-16 06:00:00 +1100 Graham Williams>
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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import 'package:radiopod/screens/transfer_widgets/import_action_card.dart';
import 'package:radiopod/screens/transfer_widgets/import_message_banner.dart';
import 'package:radiopod/screens/transfer_widgets/playlist_file_export.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/utils/opml.dart';

/// Import and export of podcast subscriptions in OPML, the format every
/// podcast app reads and writes.
///
/// A section of its own beside the playlist import and export, because the
/// two hold different things: a playlist file lists audio streams, an OPML
/// file lists feeds. Only the feeds travel; what has been heard stays here.

class PodcastTransferSection extends StatefulWidget {
  const PodcastTransferSection({super.key});

  @override
  State<PodcastTransferSection> createState() => _PodcastTransferSectionState();
}

class _PodcastTransferSectionState extends State<PodcastTransferSection> {
  bool _loading = false;
  String? _message;
  bool _error = false;

  void _setMsg(String msg, {bool error = false}) => setState(() {
    _message = msg;
    _error = error;
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final n = provider.podcastFeeds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Podcasts', style: Theme.of(context).textTheme.titleLarge),
        const Gap(8),
        Text(
          'Bring in the podcasts you follow in another app, or take them '
          'with you, as an OPML file. Only the list of podcasts moves; what '
          'you have heard stays here. A podcast you already have is not '
          'added twice.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        if (_message != null) ...[
          const Gap(12),
          ImportMessageBanner(message: _message!, isError: _error, cs: cs),
        ],
        const Gap(16),
        ImportActionCard(
          icon: Icons.podcasts,
          title: 'Import podcasts from OPML',
          subtitle: 'Select an .opml file exported from a podcast app.',
          loading: _loading,
          onTap: _import,
        ),
        const Gap(12),
        ImportActionCard(
          icon: Icons.download_outlined,
          title: 'Export podcasts as OPML',
          subtitle: n == 0
              ? 'No podcasts saved yet.'
              : 'Save all $n podcast${n == 1 ? '' : 's'} as one file.',
          loading: _loading,
          onTap: n == 0
              ? () => _setMsg('Save a podcast from Search first.')
              : () => _export(provider),
        ),
      ],
    );
  }

  Future<void> _import() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      // 20261016 gjw No filter on a phone. Android and iOS filter by file
      // type, they have none registered for .opml, and filtering on xml as
      // well hides the .opml files the user came for. The content decides.

      final mobile =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select an OPML file',
        type: mobile ? FileType.any : FileType.custom,
        allowedExtensions: mobile ? null : opmlExtensions,
      );
      if (file == null) return;

      final content = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );
      final feeds = parseOpml(content);
      if (feeds.isEmpty) {
        _setMsg('No podcasts found in "${file.name}".', error: true);

        return;
      }

      if (!mounted) return;
      final (added, saveError) = await context
          .read<AppProvider>()
          .importPodcasts(feeds);
      if (saveError != null) {
        _setMsg('Import failed to save: $saveError', error: true);

        return;
      }

      final n = feeds.length;
      _setMsg(
        'Found $n podcast${n == 1 ? '' : 's'} in "${file.name}", $added new '
        'to your library. ${added == 0 ? '' : 'Their episodes are being '
                  'fetched and will appear in Stations shortly.'}',
      );
    } on FormatException catch (e) {
      _setMsg(e.message, error: true);
    } catch (e, st) {
      debugPrint('[Transfer] OPML import error: $e\n$st');
      _setMsg('Import failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(AppProvider provider) async {
    final feeds = provider.podcastFeeds;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final path = await saveOpmlFile(feeds);
      if (path == null) return;
      _setMsg(
        'Saved ${feeds.length} podcast${feeds.length == 1 ? '' : 's'} '
        'as OPML to $path',
      );
    } catch (e, st) {
      debugPrint('[Transfer] OPML export error: $e\n$st');
      _setMsg('Export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
