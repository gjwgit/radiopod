/// SearchScreen — find stations in the Radio-Browser database.
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

import 'package:provider/provider.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/search_widgets/search_controls.dart';
import 'package:radiopod/screens/search_widgets/search_intro.dart';
import 'package:radiopod/screens/search_widgets/search_result_actions.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/services/podcast_index.dart';
import 'package:radiopod/services/radio_browser.dart';
import 'package:radiopod/services/view_prefs.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';
import 'package:radiopod/widgets/error_dialog.dart';
import 'package:radiopod/widgets/now_playing.dart';
import 'package:radiopod/widgets/now_playing_stop_button.dart';
import 'package:radiopod/widgets/station_tile.dart';

/// Search Radio-Browser for stations, by name, genre or location, or
/// Podcast Index for podcasts.
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

  SearchKind _kind = SearchKind.radio;
  SearchField _field = SearchField.name;
  List<Station> _results = [];
  bool _searching = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _restoreField();
  }

  Future<void> _restoreField() async {
    final byGenre = await ViewPrefs.getBool(
      ViewPrefs.searchByGenre,
      orElse: false,
    );
    final name = await ViewPrefs.getString(
      ViewPrefs.searchField,
      orElse: byGenre ? SearchField.tag.name : SearchField.name.name,
    );
    final field = SearchField.values.asNameMap()[name] ?? SearchField.name;
    final kindName = await ViewPrefs.getString(
      ViewPrefs.searchKind,
      orElse: SearchKind.radio.name,
    );
    final kind = SearchKind.values.asNameMap()[kindName] ?? SearchKind.radio;
    if (mounted) {
      setState(() {
        _field = field;
        _kind = kind;
      });
    }
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
          child: SearchControls(
            kind: _kind,
            field: _field,
            controller: _query,
            searching: _searching,
            onKind: _setKind,
            onField: _setField,
            onSearch: _search,
            trailing: NowPlayingStopButton(
              stations: [..._results, ...context.watch<AppProvider>().stations],
            ),
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (!_searched) return const SearchIntro();
    if (_results.isEmpty && _kind == SearchKind.podcast) {
      return const SearchIntro(
        message:
            'No podcasts matched. Try fewer words, or the name of the '
            'person or organisation that makes it.',
      );
    }
    if (_results.isEmpty) {
      return const SearchIntro(
        message:
            'No stations matched. Try a shorter or more general search — '
            'Radio-Browser matches on part of a name, so "classic" finds '
            'more than "ABC Classic FM". With an @place, check the place '
            'is spelt as Radio-Browser has it, e.g. @germany, not @deutschland.',
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
            keepLogo: false,
            current: now.isCurrent(station.id),
            playing: now.playing,
            connecting: now.connecting,
            loading: now.loading,
            paused: now.paused,
            failed: now.failed,
            track: now.track,
            onTap: () => now.isCurrent(station.id)
                ? (now.playing ? Player.handler.stop() : Player.handler.play())
                : _preview(station),
            trailing: SearchResultActions(
              station: station,
              saved: saved,
              onSave: () => _save(provider, station),
            ),
          );
        },
      ),
    );
  }

  void _setKind(SearchKind kind) {
    setState(() {
      _kind = kind;
      _results = [];
      _searched = false;
    });
    ViewPrefs.setString(ViewPrefs.searchKind, kind.name);
    if (_query.text.trim().isNotEmpty) _search();
  }

  void _setField(SearchField field) {
    setState(() => _field = field);
    ViewPrefs.setString(ViewPrefs.searchField, _field.name);
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
      final podcasts = _kind == SearchKind.podcast;
      final results = podcasts
          ? await PodcastIndex.search(query)
          : await RadioBrowser.search(query, field: _field);
      if (!mounted) return;
      setState(() => _results = results);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _results = []);
      await showErrorDialog(
        context,
        title: 'Podcast search unavailable',
        message:
            '${e.message} Podcasts already in your library still play and '
            'refresh as usual.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _results = []);
      final where = _kind == SearchKind.podcast
          ? 'the Podcast Index directory'
          : 'the Radio-Browser database';
      await showErrorDialog(
        context,
        title: 'Search failed',
        message:
            'Could not reach $where. Check your network connection and try '
            'again.\n\n$e',
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Play a result without saving it, so it can be auditioned first.

  Future<void> _preview(Station station) async {
    final provider = context.read<AppProvider>();
    try {
      if (station.isPodcast) {
        await provider.previewPodcast(station);
      } else {
        await provider.play(station);
      }
    } catch (e) {
      if (!mounted) return;
      await showPlayError(
        context,
        station: station,
        error: e,
        otherwise: station.isPodcast
            ? 'Its episodes could not be fetched or played. The podcast '
                  'may have moved or stopped publishing.'
            : 'Radio-Browser lists this station but its stream could not be '
                  'reached. It may be off the air.',
      );
    }
  }

  Future<void> _save(AppProvider provider, Station station) async {
    if (station.isPodcast) {
      final error = await provider.addPodcast(station);
      if (!mounted) return;
      if (error != null) {
        await showErrorDialog(
          context,
          title: 'Saved, but no episodes yet',
          message:
              '${station.name} is in your library, but its episodes could '
              'not be fetched. Refresh it from its Episodes page later.\n\n'
              '$error',
        );

        return;
      }
    } else {
      await provider.addStation(station);
    }
    if (!mounted) return;
    showPositiveSnackBar(
      context,
      'Saved ${station.name} to the top of your stations.',
    );
  }
}
