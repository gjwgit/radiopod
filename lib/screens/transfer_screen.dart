/// TransferScreen — import and export M3U and PLS playlists.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import 'package:radiopod/screens/transfer_widgets/export_choice_sheet.dart';
import 'package:radiopod/screens/transfer_widgets/import_action_card.dart';
import 'package:radiopod/screens/transfer_widgets/import_message_banner.dart';
import 'package:radiopod/screens/transfer_widgets/playlist_file_export.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/utils/playlist_file.dart';

/// Move playlists in and out of RadioPod in the open M3U and PLS formats.
///
/// These are the formats every other radio app reads, which is the point: a
/// library kept here is not trapped here. Import merges into the existing
/// library rather than replacing it, and a station already saved is reused
/// rather than duplicated.

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  bool _loading = false;
  String? _importMessage;
  bool _importError = false;
  String? _exportMessage;
  bool _exportError = false;

  void _setImportMsg(String msg, {bool error = false}) => setState(() {
    _importMessage = msg;
    _importError = error;
  });

  void _setExportMsg(String msg, {bool error = false}) => setState(() {
    _exportMessage = msg;
    _exportError = error;
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final stations = provider.stations.length;
    final playlists = provider.playlists.length;

    // 20260925 gjw MADE TO FILL THE VIEWPORT so the content stays at the
    // top. This screen is shorter than the window, and something above it
    // centres a child that does not fill the height — which left a wide band
    // of empty space above "Import" while Settings, whose content overflows,
    // sat correctly at the top. Giving the column a minimum height of the
    // viewport leaves nothing to centre.

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight.isFinite
                ? constraints.maxHeight - 48
                : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Import ──────────────────────────────────────────────────

              Text('Import', style: Theme.of(context).textTheme.titleLarge),
              const Gap(8),
              Text(
                'Bring in a playlist you already have, in the M3U, M3U8 or PLS '
                'format. The stations are added to your library and grouped into '
                'a new playlist named after the file. A station whose stream '
                'address you have already saved is reused rather than duplicated.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              if (_importMessage != null) ...[
                const Gap(12),
                ImportMessageBanner(
                  message: _importMessage!,
                  isError: _importError,
                  cs: cs,
                ),
              ],
              const Gap(16),
              ImportActionCard(
                icon: Icons.upload_file_outlined,
                title: 'Import M3U or PLS playlist',
                subtitle: 'Select a .m3u, .m3u8 or .pls file to import.',
                loading: _loading,
                onTap: _import,
              ),

              // ── Export ──────────────────────────────────────────────────
              const Gap(32),
              Text('Export', style: Theme.of(context).textTheme.titleLarge),
              const Gap(8),
              Text(
                'Save your whole library, or any one playlist, as an M3U or PLS '
                'file. Both are plain text formats that every other radio player '
                'reads, so nothing you collect here is locked in.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              if (_exportMessage != null) ...[
                const Gap(12),
                ImportMessageBanner(
                  message: _exportMessage!,
                  isError: _exportError,
                  cs: cs,
                ),
              ],
              const Gap(16),
              ImportActionCard(
                icon: Icons.download_outlined,
                title: 'Export a playlist',
                subtitle: playlists == 0
                    ? 'Export all $stations saved stations as one file.'
                    : 'Choose all $stations stations, or one of your $playlists '
                          'playlists.',
                loading: _loading,
                onTap: () => _export(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Pick a playlist file, parse it, and merge it into the library.
  ///
  /// The file's own name becomes the playlist name, which is almost always
  /// what the user meant and saves asking a question at the moment they are
  /// least interested in answering one.

  Future<void> _import() async {
    setState(() {
      _loading = true;
      _importMessage = null;
    });
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select an M3U or PLS playlist',
        type: FileType.custom,
        allowedExtensions: playlistExtensions,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();

      // 20260921 gjw Playlist files in the wild are not reliably UTF-8 —
      // older M3U files are often Latin-1 — so decode leniently rather than
      // throwing on a stray byte and losing the whole import.

      final content = utf8.decode(bytes, allowMalformed: true);
      final entries = parsePlaylist(content, detectFormat(file.name, content));
      if (entries.isEmpty) {
        _setImportMsg('No stations found in "${file.name}".', error: true);

        return;
      }

      if (!mounted) return;
      final name = _playlistNameFor(file.name);
      final (added, saveError) = await context
          .read<AppProvider>()
          .importEntries(entries, playlistName: name);

      if (saveError != null) {
        // Do not claim success: the stations are listed but not on the Pod.

        _setImportMsg('Import failed to save: $saveError', error: true);

        return;
      }

      _setImportMsg(
        'Imported ${entries.length} station${entries.length == 1 ? '' : 's'} '
        'from "${file.name}" into the playlist "$name" '
        '($added new to your library).',
      );
    } catch (e, st) {
      debugPrint('[Transfer] import error: $e\n$st');
      _setImportMsg('Import failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The playlist name for an imported file: its name without the extension.

  String _playlistNameFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;

    return base.trim().isEmpty ? 'Imported' : base.trim();
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _export(AppProvider provider) async {
    final choice = await showModalBottomSheet<ExportChoice>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExportChoiceSheet(
        allStations: provider.stations,
        playlists: provider.playlists,
        stationsOf: provider.stationsOf,
      ),
    );
    if (choice == null || !mounted) return;

    setState(() {
      _loading = true;
      _exportMessage = null;
    });
    try {
      final path = await savePlaylistFile(
        stations: choice.stations,
        name: choice.name,
        format: choice.format,
      );
      if (path == null) return;
      _setExportMsg(
        'Saved ${choice.stations.length} stations as '
        '${choice.format.label} to $path',
      );
    } catch (e, st) {
      debugPrint('[Transfer] export error: $e\n$st');
      _setExportMsg('Export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
