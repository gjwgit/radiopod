/// SearchScreen — find stations in the Radio-Browser database.
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

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/search_widgets/search_intro.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/services/radio_browser.dart';
import 'package:radiopod/services/view_prefs.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';
import 'package:radiopod/widgets/now_playing.dart';
import 'package:radiopod/widgets/station_tile.dart';

/// Search Radio-Browser by station name or by genre.
///
/// Results are not saved anywhere until the user taps Save on one. Tapping a
/// result plays it straight away without saving, so a station can be
/// auditioned before it joins the library.

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  SearchField _field = SearchField.name;
  List<Station> _results = [];
  bool _searching = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    ViewPrefs.getBool(ViewPrefs.searchByGenre, orElse: false).then((byGenre) {
      if (mounted && byGenre) setState(() => _field = SearchField.tag);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              SegmentedButton<SearchField>(
                segments: [
                  for (final f in SearchField.values)
                    ButtonSegment(value: f, label: Text(f.label)),
                ],
                selected: {_field},
                onSelectionChanged: _setField,
              ),
              const Gap(12),
              TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: _field == SearchField.name
                      ? 'Station name, e.g. ABC Classic'
                      : 'Genre, e.g. jazz',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: MarkdownTooltip(
                    message: '''

                    **Search**

                    Ask the community-run Radio-Browser database for matching
                    stations. Only your search text and the app name are sent.

                    ''',
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _searching ? null : _search,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (!_searched) return const SearchIntro();
    if (_results.isEmpty) {
      return const SearchIntro(
        message:
            'No stations matched. Try a shorter or more general search — '
            'Radio-Browser matches on part of a name, so "classic" finds '
            'more than "ABC Classic FM".',
      );
    }

    final provider = context.watch<AppProvider>();

    return NowPlayingBuilder(
      builder: (context, now) => ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, i) {
          final station = _results[i];
          final saved = provider.isSaved(station.url);

          return StationTile(
            station: station,
            current: now.isCurrent(station.id),
            playing: now.playing,
            connecting: now.connecting,
            failed: now.failed,
            track: now.track,
            onTap: () => now.isCurrent(station.id)
                ? (now.playing ? Player.handler.stop() : Player.handler.play())
                : _preview(station),
            trailing: saved
                ? const MarkdownTooltip(
                    message: '''

                  **Already saved**

                  This station is in your library. Find it on the Stations
                  screen to play it or add it to a playlist.

                  ''',
                    child: Icon(Icons.check),
                  )
                : MarkdownTooltip(
                    message: '''

                  **Save**

                  Add this station to your library. It is written encrypted to
                  your Solid Pod.

                  ''',
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _save(provider, station),
                    ),
                  ),
          );
        },
      ),
    );
  }

  void _setField(Set<SearchField> selection) {
    setState(() => _field = selection.first);
    ViewPrefs.setBool(ViewPrefs.searchByGenre, _field == SearchField.tag);
    if (_searched) _search();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searched = true;
    });
    try {
      final results = await RadioBrowser.search(query, field: _field);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _results = []);
      await showErrorDialog(
        context,
        title: 'Search failed',
        message:
            'Could not reach the Radio-Browser database. Check your network '
            'connection and try again.\n\n$e',
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Play a result without saving it, so it can be auditioned first.

  Future<void> _preview(Station station) async {
    try {
      await context.read<AppProvider>().play(station);
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: 'Cannot play ${station.name}',
        message:
            'Radio-Browser lists this station but its stream could not be '
            'reached. It may be off the air.\n\n$e',
      );
    }
  }

  Future<void> _save(AppProvider provider, Station station) async {
    await provider.addStation(station);
    if (!mounted) return;
    showPositiveSnackBar(
      context,
      'Saved ${station.name} to the top of your stations.',
    );
  }
}
