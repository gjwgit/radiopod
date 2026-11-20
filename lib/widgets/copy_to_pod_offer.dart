/// Copy to Pod offer — ask, just after a login, to copy the device library up.
///
// Time-stamp: <Thursday 2026-10-15 06:00:00 +1100 Graham Williams>
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

import 'package:provider/provider.dart';

import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';

/// Offer to copy stations saved while logged out up to the Pod.
///
/// 20261015 gjw Run just after a login has moved the library to the Pod.
/// Copy to Pod in Settings did the work, but nobody logging in thought to
/// look there, and the stations they had just been listening to vanished
/// from the list. Asking keeps the copy a deliberate choice, which matters
/// on a borrowed device (§4), while putting it where it is noticed. Not now
/// leaves the stations held, and Settings still offers them.

Future<void> offerCopyToPod(BuildContext context) async {
  final provider = context.read<AppProvider>();
  final count = await provider.localOnlyCount();
  if (count == 0 || !context.mounted) return;

  final stations = '$count station${count == 1 ? '' : 's'}';
  final copy = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Copy your stations to your Pod?'),
      content: Text(
        'This device holds $stations saved before you logged in, which '
        'your Pod does not have. Copy them up, with their playlists, so they '
        'are in your library here and on your other devices?\n\n'
        'Stations your Pod already has are left alone. If this is not your '
        'device, choose Not now; Settings will still offer to copy them.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Copy to Pod'),
        ),
      ],
    ),
  );
  if (copy != true || !context.mounted) return;

  final (added, error) = await provider.copyLocalToPod();
  if (!context.mounted) return;

  if (error != null) {
    await showErrorDialog(
      context,
      title: 'Could not copy to your Pod',
      message:
          'The stations are still held on this device, and Settings will '
          'offer to copy them again.\n\n$error',
    );

    return;
  }
  showPositiveSnackBar(
    context,
    'Copied $added station${added == 1 ? '' : 's'} to your Pod.',
  );
}
