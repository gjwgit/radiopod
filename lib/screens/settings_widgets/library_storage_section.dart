/// LibraryStorageSection — where the library lives, and what to do about it.
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
import 'package:radiopod/services/local_store.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';

/// Tells the user which of the two stores is in use and why.
///
/// This is the first thing on the Settings screen because it answers the
/// question someone who tapped Continue will actually have: where did my
/// stations go, and are they safe. The wording changes with [isLocal] rather
/// than hedging over both cases at once.

class LibraryStorageSection extends StatefulWidget {
  const LibraryStorageSection({super.key});

  @override
  State<LibraryStorageSection> createState() => _LibraryStorageSectionState();
}

class _LibraryStorageSectionState extends State<LibraryStorageSection> {
  /// Stations on this device that the Pod does not have, or null until
  /// counted. Only meaningful when logged in.

  int? _localOnly;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _count());
  }

  Future<void> _count() async {
    final n = await context.read<AppProvider>().localOnlyCount();
    if (mounted) setState(() => _localOnly = n);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final local = provider.isLocal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where your stations are kept',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Gap(8),
        _banner(cs, local: local),
        const Gap(12),
        _paragraph(
          cs,
          local
              ? 'You are not logged in, so RadioPod is keeping your stations '
                    'and playlists on this device, in the app\'s private '
                    'storage. Nothing is sent anywhere. They will still be '
                    'here next time you open the app.'
              : 'You are logged in, so your stations and playlists live on '
                    'your Solid Pod, encrypted with your security key before '
                    'they leave this device. The server holding them — '
                    'including its administrators — cannot read them.',
        ),
        const Gap(12),
        _paragraph(
          cs,
          local
              ? 'The device copy is not encrypted. It holds no more than a '
                    'playlist file would — names and stream addresses, never '
                    'a password or a key. Log in at any time and Settings '
                    'will offer to copy it up to your Pod.'
              : 'A plain copy of the same names and addresses also stays on '
                    'this device, because Android Auto starts RadioPod before '
                    'a login can happen and will not wait for one. The car '
                    'browses that copy.',
        ),

        if (!local && (_localOnly ?? 0) > 0) ...[
          const Gap(16),
          _paragraph(
            cs,
            'This device is holding ${_localOnly!} station'
            '${_localOnly == 1 ? '' : 's'} that your Pod does not have, '
            'probably saved before you logged in.',
          ),
          const Gap(8),
          MarkdownTooltip(
            message: '''

            **Copy to Pod**

            Add the stations held on this device to your Pod. Stations your
            Pod already has are matched by stream address and left alone, so
            this never creates duplicates and is safe to press twice.

            ''',
            child: FilledButton.icon(
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Copy to Pod'),
              onPressed: _busy ? null : _copyToPod,
            ),
          ),
        ],

        const Gap(16),
        MarkdownTooltip(
          message: local
              ? '''

                **Delete local stations**

                You are not logged in, so this device is the ONLY place your
                stations and playlists are stored. Deleting them cannot be
                undone.

                '''
              : '''

                **Clear device copy**

                Forget the unencrypted copy held on this device for Android
                Auto. Your Pod is not touched and the copy is rebuilt the
                next time your library loads.

                ''',
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: Text(local ? 'Delete local stations' : 'Clear device copy'),
            onPressed: _busy ? null : () => _clear(local: local),
          ),
        ),
      ],
    );
  }

  /// A one-line badge naming the store, so the answer is visible without
  /// reading the paragraphs.

  Widget _banner(ColorScheme cs, {required bool local}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: local ? cs.secondaryContainer : cs.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(
          local ? Icons.phone_android : Icons.cloud_done_outlined,
          size: 20,
          color: local ? cs.onSecondaryContainer : cs.onPrimaryContainer,
        ),
        const Gap(8),
        Expanded(
          child: Text(
            local ? 'Stored on this device' : 'Stored on your Solid Pod',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: local ? cs.onSecondaryContainer : cs.onPrimaryContainer,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _paragraph(ColorScheme cs, String text) =>
      Text(text, style: TextStyle(color: cs.onSurfaceVariant));

  Future<void> _copyToPod() async {
    setState(() => _busy = true);
    try {
      final (added, error) = await context.read<AppProvider>().copyLocalToPod();
      if (!mounted) return;

      if (error != null) {
        await showErrorDialog(
          context,
          title: 'Could not copy to your Pod',
          message: 'Nothing was changed on your Pod.\n\n$error',
        );

        return;
      }
      showPositiveSnackBar(
        context,
        added == 0
            ? 'Your Pod already had everything on this device.'
            : 'Copied $added station${added == 1 ? '' : 's'} to your Pod.',
      );
      await _count();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Clear the device copy, confirming first when it is the only copy.

  Future<void> _clear({required bool local}) async {
    if (local) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete local stations?'),
          content: const Text(
            'You are not logged in, so this device is the only place your '
            'stations and playlists are stored. This cannot be undone.\n\n'
            'To keep them, log in to a Solid Pod first and use Copy to Pod.',
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
    }

    await LocalStore.clear();
    if (!mounted) return;

    // When the device IS the library, the in-memory copy has to go too or
    // the screens would keep showing stations that no longer exist.

    if (local) await context.read<AppProvider>().load();
    if (!mounted) return;

    showPositiveSnackBar(
      context,
      local ? 'Local stations deleted.' : 'Device copy cleared.',
    );
    await _count();
  }
}
