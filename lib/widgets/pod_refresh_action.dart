/// Reusable "refresh from Pod" app bar action.
///
// Time-stamp: <Saturday 2026-10-17 05:21:09 +1100 Graham Williams>
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

/// Reloads the app's in-memory data from the Pod (which may have been updated
/// by another instance of the app or another app sharing the same Pod data),
/// then reports — via a simple OK dialog — whether anything changed.
///
/// REUSE PATTERN (for other apps in the suite):
///   1. Give the app's provider/service a `Future<bool> refreshFromPod()` that
///      reloads from the Pod and returns true iff the data changed (snapshot a
///      content signature, reload, compare — see RadioPod's AppProvider).
///   2. Add this action to the SolidAppBarConfig actions list:
///        actions: [
///          buildPodRefreshAction(
///            context: context,
///            onRefresh: provider.refreshFromPod,
///          ),
///        ]
///   3. Copy this file into the new app and adjust the import of nothing else —
///      it only depends on solidui and flutter.

library;

import 'package:flutter/material.dart';

import 'package:solidui/solidui.dart';

/// Builds the refresh [SolidAppBarAction].
///
/// [onRefresh] reloads the in-memory data from the Pod and returns true if the
/// data changed (the Pod had been updated elsewhere), false if already current.
///
/// [isOnPod], when given, says whether a Pod is in use at the moment of the
/// tap. See [handlePodRefresh].
SolidAppBarAction buildPodRefreshAction({
  required BuildContext context,
  required Future<bool> Function() onRefresh,
  bool Function()? isOnPod,
  String tooltip = 'Refresh from Pod',
}) {
  return SolidAppBarAction(
    icon: Icons.refresh,
    tooltip: tooltip,
    onPressed: () => handlePodRefresh(
      context: context,
      onRefresh: onRefresh,
      isOnPod: isOnPod,
    ),
  );
}

/// Runs the refresh and shows the appropriate OK dialog.
///
/// Kept public and separate from [buildPodRefreshAction] so it can also be
/// triggered from elsewhere (e.g. a menu item or pull-to-refresh).
///
/// 20261016 gjw With no login, [onRefresh] reloads only the device's own
/// copy, and the dialog used to say the data was up to date with the Pod —
/// which hid that the Pod was never asked, and left podcasts saved on
/// another device missing with no explanation. When [isOnPod] says no Pod
/// is in use, the refresh still runs and the dialog says so instead.
Future<void> handlePodRefresh({
  required BuildContext context,
  required Future<bool> Function() onRefresh,
  bool Function()? isOnPod,
}) async {
  bool changed;
  try {
    changed = await onRefresh();
  } catch (e) {
    if (!context.mounted) return;
    await _showRefreshDialog(
      context,
      title: 'Refresh failed',
      message: 'Could not refresh from your Pod.\n\n$e',
      icon: Icons.error_outline,
      iconColor: Colors.red,
    );
    return;
  }

  if (!context.mounted) return;

  if (isOnPod != null && !isOnPod()) {
    await _showRefreshDialog(
      context,
      title: 'Not logged in',
      message:
          'This app is not logged in to a Pod, so the library shown is the '
          'one kept on this device. Nothing was read from a Pod.\n\n'
          'To see what is saved on your Pod, log in from the profile menu.',
      icon: Icons.cloud_off_outlined,
      iconColor: Colors.orange,
    );

    return;
  }

  if (changed) {
    await _showRefreshDialog(
      context,
      title: 'Data updated',
      message:
          'Your data has been updated from changes made in your Pod '
          'outside this app.',
      icon: Icons.cloud_download_outlined,
      iconColor: Colors.green,
    );
  } else {
    await _showRefreshDialog(
      context,
      title: 'Already up to date',
      message:
          'Your data is already up to date with your Pod. No changes were '
          'found.',
      icon: Icons.check_circle_outline,
      iconColor: Colors.blue,
    );
  }
}

Future<void> _showRefreshDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  required Color iconColor,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
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
