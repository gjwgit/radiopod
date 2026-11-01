/// Error dialog — modal, acknowledged reporting of a failure.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
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
import 'package:radiopod/services/cast_playback.dart';

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
  IconData icon = Icons.error_outline,
}) {
  final cs = Theme.of(context).colorScheme;
  final fault = icon == Icons.error_outline;

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(icon, color: fault ? cs.error : cs.primary),
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

/// Report why [station] did not play: [otherwise] for a fault, or, for a
/// podcast with nothing left ([NothingToPlay]), what is actually the case.
///
/// 20261018 gjw A podcast with every episode heard was reported as a dead
/// stream, with advice to find it again in Search. That is not a fault, and
/// it gets an information icon rather than an error one.

Future<void> showPlayError(
  BuildContext context, {
  required Station station,
  required Object error,
  required String otherwise,
}) {
  if (error is NothingToPlay) {
    return showErrorDialog(
      context,
      title: error.title,
      message: error.message,
      icon: Icons.info_outline,
    );
  }

  return showErrorDialog(
    context,
    title: 'Cannot play ${station.name}',
    message: '$otherwise\n\n$error',
  );
}
