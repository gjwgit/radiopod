/// Refresh podcasts — fetch every podcast's feed from the toolbar.
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

library;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:solidui/solidui.dart' show SolidAppBarAction;

import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';

/// The toolbar's Refresh podcasts button, shown while there are podcasts.
///
/// 20261017 gjw It took the place of Refresh from Pod, which moved to the
/// profile menu (solidui's `SolidAppBarConfig.onRefreshFromPod`). Feeds are
/// also fetched after every load, so this is for when a new episode is
/// expected now: the morning news, a show just out.

SolidAppBarAction buildPodcastRefreshAction({
  required BuildContext context,
  required bool visible,
}) => SolidAppBarAction(
  id: 'refresh-podcasts',
  icon: Icons.refresh,
  visible: visible,
  tooltip: '''

  **Refresh podcasts**

  Check every podcast you have saved for new episodes.

  Each podcast's feed is fetched from its publisher. This also happens
  every time your library loads.

  ''',
  onPressed: () => _refresh(context),
);

Future<void> _refresh(BuildContext context) async {
  final provider = context.read<AppProvider>();
  final n = provider.stations.where((s) => s.isPodcast).length;
  showPositiveSnackBar(
    context,
    'Checking $n ${_podcasts(n)} for new episodes.',
  );

  final result = await provider.refreshAllPodcasts();
  if (!context.mounted) return;

  if (result.failed.isNotEmpty) {
    await showErrorDialog(
      context,
      title: 'Some podcasts could not be refreshed',
      message: podcastRefreshMessage(result),
    );

    return;
  }
  showPositiveSnackBar(context, podcastRefreshMessage(result));
}

/// What a refresh of every podcast found, in a sentence or two.

String podcastRefreshMessage(PodcastRefresh r) {
  final checked = r.podcasts - r.failed.length;
  final found = switch (r.newCasts) {
    0 => 'no new episodes',
    1 => '1 new episode',
    final n => '$n new episodes',
  };
  final summary = 'Checked $checked ${_podcasts(checked)}: $found.';
  if (r.failed.isEmpty) return summary;

  return '$summary\n\n'
      'Could not fetch ${r.failed.join(', ')}. The publisher may be '
      'unreachable just now, or this device offline; '
      '${r.failed.length == 1 ? 'its' : 'their'} episodes are as they were, '
      'and will be checked again next time.';
}

String _podcasts(int n) => n == 1 ? 'podcast' : 'podcasts';
