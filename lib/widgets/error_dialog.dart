/// Error dialog — modal, acknowledged reporting of a failure.
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

/// Report [message] in a dialog the user must dismiss.
///
/// Errors get a dialog rather than a SnackBar because they need
/// acknowledgement: a station that would not play, or a save that did not
/// reach the Pod, is not something to let slide past in four seconds.
/// SnackBars stay for transient confirmations of things that worked.

Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final cs = Theme.of(context).colorScheme;

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error),
          const Gap(8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
