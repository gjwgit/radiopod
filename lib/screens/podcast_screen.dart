/// PodcastScreen — a podcast's casts, to read about, play, or skip.
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

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';

import 'package:radiopod/models/cast.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/podcast_widgets/cast_tile.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/cast_controls.dart';
import 'package:radiopod/widgets/error_dialog.dart';
import 'package:radiopod/widgets/now_playing.dart';
import 'package:radiopod/widgets/station_tile.dart';

/// Every cast of one podcast, newest first.
///
/// 20261016 gjw Reached from the Casts action on a podcast's row in
/// Stations. The row itself stays the quick way in — a tap plays the
/// latest cast still to hear — and this page is for choosing: reading the
/// show notes, playing an older cast, or switching off the ones not wanted
/// so the podcast skips them.

class PodcastScreen extends StatefulWidget {
  final String podcastId;

  const PodcastScreen({super.key, required this.podcastId});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final podcast = provider.stations
        .where((s) => s.id == widget.podcastId)
        .firstOrNull;

    // Deleted from under the page, e.g. on another device and then synced.

    if (podcast == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This podcast is no longer saved.')),
      );
    }

    final casts = provider.castsOf(podcast.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(podcast.name),
        actions: [
          if (casts.isNotEmpty) _skipAll(provider, podcast, casts),
          MarkdownTooltip(
            message: '''

            **Refresh**

            Fetch this podcast's feed from its publisher now, to pick up any
            new episodes. Your progress and skipped episodes are kept.

            ''',
            child: IconButton(
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _refreshing ? null : () => _refresh(provider),
            ),
          ),
        ],
      ),
      // 20261016 gjw The timeline sits at the TOP of the body, as on the
      // Stations screen, not in bottomNavigationBar. A floating SnackBar —
      // "Saved … to your stations" follows the listener here from Search —
      // is laid out above the bottom bar, and when it would not fit Scaffold
      // threw mid-layout: the list was never laid out and the page showed
      // no casts, no titles and no show notes.
      body: Column(
        children: [
          const CastControls(),
          Expanded(child: _casts(provider, podcast, casts)),
        ],
      ),
    );
  }

  Widget _casts(AppProvider provider, Station podcast, List<Cast> casts) =>
      NowPlayingBuilder(
        builder: (context, now) => ListView.builder(
          itemCount: casts.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return _header(provider, podcast);
            final cast = casts[i - 1];
            final current =
                now.isCurrent(podcast.id) && now.isCurrentCast(cast.guid);

            return CastTile(
              key: ValueKey(cast.guid),
              cast: cast,
              current: current,
              playing: now.playing,
              onTap: () => current
                  ? (now.playing
                        ? Player.handler.pause()
                        : Player.handler.play())
                  : _play(provider, podcast, cast.guid),
              onEnabled: (on) =>
                  provider.setCastDisabled(podcast.id, cast.guid, !on),
              onPlayed: (played) =>
                  provider.setCastPlayed(podcast.id, cast.guid, played),
            );
          },
        ),
      );

  /// Skip every cast, or, once all are skipped, bring them all back.
  ///
  /// 20261016 gjw One tap for a podcast followed for its next episode only,
  /// where the back catalogue is not wanted. Offered as its own undo, since
  /// putting twenty switches back by hand is not.

  Widget _skipAll(AppProvider provider, Station podcast, List<Cast> casts) {
    final allSkipped = casts.every((c) => c.disabled);

    return MarkdownTooltip(
      message: allSkipped
          ? '''

            **Unskip all**

            Put every episode back in the podcast's turn, so it plays them
            again, newest first. Episodes already heard stay heard.

            '''
          : '''

            **Skip all**

            Skip every episode listed here, so the podcast plays none of them
            and waits for the next new one. A tap on an episode still plays it.

            ''',
      child: TextButton.icon(
        icon: Icon(allSkipped ? Icons.playlist_add_check : Icons.block),
        label: Text(allSkipped ? 'Unskip all' : 'Skip all'),
        onPressed: () => _setAllSkipped(provider, podcast, !allSkipped),
      ),
    );
  }

  Future<void> _setAllSkipped(
    AppProvider provider,
    Station podcast,
    bool skip,
  ) async {
    final error = await provider.setAllCastsDisabled(podcast.id, skip);
    if (!mounted) return;
    if (error != null) {
      await showErrorDialog(
        context,
        title: 'Saved on this device only',
        message: 'The change could not be written to your Pod.\n\n$error',
      );

      return;
    }
    showPositiveSnackBar(
      context,
      skip
          ? 'Every episode of ${podcast.name} is skipped.'
          : 'No episodes skipped.',
    );
  }

  Widget _header(AppProvider provider, Station podcast) {
    final cs = Theme.of(context).colorScheme;
    final casts = provider.castsOf(podcast.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            podcastDetails(
              podcast,
              toPlay: provider.castsToPlay(podcast.id),
              total: casts.length,
            ),
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const Gap(4),
          Text(
            casts.isEmpty
                ? 'No episodes yet. Refresh to fetch them from the publisher.'
                : 'Tap the podcast in Stations to play the latest episode still '
                      'to hear, then each older one in turn. Played episodes '
                      'stay here, greyed, as do skipped episodes.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _play(AppProvider provider, Station podcast, String guid) async {
    try {
      await provider.playCast(podcast.id, guid);
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: 'Cannot play this episode',
        message:
            'The publisher\'s server did not deliver it. It may have been '
            'withdrawn; Refresh fetches the current list.\n\n$e',
      );
    }
  }

  Future<void> _refresh(AppProvider provider) async {
    setState(() => _refreshing = true);
    final error = await provider.refreshPodcast(widget.podcastId);
    if (!mounted) return;
    setState(() => _refreshing = false);

    if (error != null) {
      await showErrorDialog(
        context,
        title: 'Could not refresh',
        message: 'The episodes below are as they were.\n\n$error',
      );

      return;
    }
    showPositiveSnackBar(context, 'Episodes are up to date.');
  }
}
