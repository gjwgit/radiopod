/// StationPullRefresh — pull the Stations list down to refresh it.
///
// Time-stamp: <Wednesday 2026-10-28 10:00:00 +1100 Graham Williams>
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
import 'package:radiopod/widgets/podcast_refresh_action.dart';

/// Pulling the list down reloads the library from the Pod, when logged in,
/// and checks every podcast for new episodes: the profile menu's Refresh
/// from Pod and the toolbar's Refresh podcasts in one gesture.
///
/// [builder] is told whether a pull is under way. A Pod reload sets
/// [AppProvider.busy], and the screen would otherwise swap the list for its
/// own spinner beneath the one being pulled, dropping the gesture's list.
///
/// Every child must be scrollable even when it fits, or there is nothing to
/// pull: see [pullableScrollPhysics] and [PullableFill].

class StationPullRefresh extends StatefulWidget {
  final Widget Function(BuildContext context, bool pulling) builder;

  const StationPullRefresh({super.key, required this.builder});

  @override
  State<StationPullRefresh> createState() => _StationPullRefreshState();
}

class _StationPullRefreshState extends State<StationPullRefresh> {
  bool _pulling = false;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: widget.builder(context, _pulling),
  );

  Future<void> _refresh() async {
    final provider = context.read<AppProvider>();
    setState(() => _pulling = true);
    try {
      final onPod = provider.source == LibrarySource.pod;
      final changed = onPod && await provider.refreshFromPod();

      // A Pod load starts a refresh of every feed; this joins that run
      // rather than fetching each feed twice.

      final podcasts = await provider.refreshAllPodcasts();
      if (!mounted) return;

      if (onPod && provider.error != null) {
        await showErrorDialog(
          context,
          title: 'Could not refresh from your Pod',
          message: provider.error!,
        );

        return;
      }

      final message = [
        if (onPod)
          changed
              ? 'Your stations were updated from your Pod.'
              : 'Your stations are up to date with your Pod.',
        if (podcasts.podcasts > 0) podcastRefreshMessage(podcasts),
      ].join('\n\n');

      if (podcasts.failed.isNotEmpty) {
        await showErrorDialog(
          context,
          title: 'Some podcasts could not be refreshed',
          message: message,
        );
      } else if (message.isNotEmpty) {
        showPositiveSnackBar(context, message);
      }
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }
}

/// Lets a list too short to scroll still be pulled down.

const pullableScrollPhysics = AlwaysScrollableScrollPhysics();

/// A non-scrolling [child], such as the empty state, made pullable while
/// still filling and centred in the space it is given.

class PullableFill extends StatelessWidget {
  final Widget child;

  const PullableFill({super.key, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: pullableScrollPhysics,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );
}
