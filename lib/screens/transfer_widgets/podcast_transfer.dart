/// PodcastTransfer — podcasts in and out of RadioPod as OPML.
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
import 'package:provider/provider.dart';

import 'package:radiopod/screens/transfer_widgets/playlist_file_export.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/utils/opml.dart';

/// Import and export of podcast subscriptions in OPML, the format every
/// podcast app reads and writes. Only the feeds travel; what has been heard
/// stays here.
///
/// 20261021 gjw A mixin for the Transfer screen's state rather than a section
/// of its own, so the OPML actions sit under the screen's Import and Export
/// headings beside the playlist ones, and report through the same banners.

mixin PodcastTransfer<T extends StatefulWidget> on State<T> {
  /// Show [msg] under the Import heading.

  void setImportMsg(String msg, {bool error = false});

  /// Show [msg] under the Export heading.

  void setExportMsg(String msg, {bool error = false});

  /// Mark a transfer as running, or finished.

  void setBusy(bool busy);

  Future<void> importPodcasts() async {
    setBusy(true);
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
        setImportMsg('No podcasts found in "${file.name}".', error: true);

        return;
      }

      if (!mounted) return;
      final (added, saveError) = await context
          .read<AppProvider>()
          .importPodcasts(feeds);
      if (saveError != null) {
        setImportMsg('Import failed to save: $saveError', error: true);

        return;
      }

      final n = feeds.length;
      setImportMsg(
        'Found $n podcast${n == 1 ? '' : 's'} in "${file.name}", $added new '
        'to your library. ${added == 0 ? '' : 'Their episodes are being '
                  'fetched and will appear in Stations shortly.'}',
      );
    } on FormatException catch (e) {
      setImportMsg(e.message, error: true);
    } catch (e, st) {
      debugPrint('[Transfer] OPML import error: $e\n$st');
      setImportMsg('Import failed: $e', error: true);
    } finally {
      if (mounted) setBusy(false);
    }
  }

  Future<void> exportPodcasts(AppProvider provider) async {
    final feeds = provider.podcastFeeds;
    if (feeds.isEmpty) {
      setExportMsg('Save a podcast from Search first.');

      return;
    }
    setBusy(true);
    try {
      final path = await saveOpmlFile(feeds);
      if (path == null) return;
      setExportMsg(
        'Saved ${feeds.length} podcast${feeds.length == 1 ? '' : 's'} '
        'as OPML to $path',
      );
    } catch (e, st) {
      debugPrint('[Transfer] OPML export error: $e\n$st');
      setExportMsg('Export failed: $e', error: true);
    } finally {
      if (mounted) setBusy(false);
    }
  }
}
