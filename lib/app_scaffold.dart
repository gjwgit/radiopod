/// RadioPod — application scaffold configuration.
///
// Time-stamp: <Friday 2026-09-25 05:44:56 +1000 Graham Williams>
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
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/playlists_screen.dart';
import 'package:radiopod/screens/search_screen.dart';
import 'package:radiopod/screens/settings_screen.dart';
import 'package:radiopod/screens/stations_screen.dart';
import 'package:radiopod/screens/stations_widgets/new_station_dialog.dart';
import 'package:radiopod/screens/transfer_screen.dart';
import 'package:radiopod/services/app_provider.dart'
    show AppProvider, StartupPhase;
import 'package:radiopod/services/captions/caption_service.dart';
import 'package:radiopod/services/captions/speech_model.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/widgets/caption_panel.dart';
import 'package:radiopod/widgets/pod_refresh_action.dart';

const appScaffold = AppScaffold();

/// Index of the Stations tab in the menu below, which owns the New station
/// action in the app bar.

const _stationsTab = 0;

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  /// Which tab is showing, so an action can belong to one screen.
  ///
  /// The app bar is shared by every screen, but New station only makes sense
  /// on Stations. It was first tried as a floating button on the list
  /// itself, which sat over the last station — the same overlap that had to
  /// be undone when the now-playing bar was removed.

  int _tab = _stationsTab;

  /// The station on air, for the CC button: it appears once a station has
  /// been started, and is greyed out when that station's language has no
  /// speech model. Only a change of station or of its language rebuilds,
  /// and the stream is built once, not per build, so each rebuild does not
  /// open a fresh subscription to the media session.
  ///
  /// Only touched where captions exist, which also keeps widget tests — run
  /// with no media session at all — clear of Player.handler.

  late final Stream<Station?> _station = CaptionService.instance.supported
      ? Player.handler.currentStation.distinct(
          (a, b) => a?.id == b?.id && a?.language == b?.language,
        )
      : Stream.value(null);

  /// Add a station by hand.
  ///
  /// Lives here rather than in StationsScreen because the app bar is built
  /// here. The dialog constructs the station and this saves it, so the
  /// dialog needs no provider. The duplicate test is the same stream-URL
  /// match the library uses everywhere else.

  Future<void> _newStation() async {
    final provider = context.read<AppProvider>();
    final station = await showNewStationDialog(
      context,
      isDuplicate: provider.isSaved,
    );
    if (station == null || !mounted) return;

    await provider.addStation(station);
    if (!mounted) return;
    showPositiveSnackBar(
      context,
      'Added ${station.name} to the top of your stations.',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initKeys());
  }

  Future<void> _initKeys() async {
    final provider = context.read<AppProvider>();
    provider.setStartupPhase(StartupPhase.unlocking);
    try {
      // 20260921 gjw No WebID means the user tapped Continue at the login
      // screen. That is a supported way to run RadioPod, not a failure, so
      // skip the security key — there is nothing to decrypt — and load the
      // library straight from the device. Returning early here, as this did
      // before, left someone who chose Continue with a permanently empty
      // Stations list and no way to tell why.

      final webId = await getWebId();
      final loggedIn = webId != null && webId.isNotEmpty;

      // 20260922 gjw Tell the provider what we just found out rather than
      // letting it ask solidpod again. `isUserLoggedIn` starts by probing the
      // keychain with a real write and delete; on a macOS Developer ID build
      // with no embedded provisioning profile that probe lands in the legacy
      // login keychain and macOS demands the keychain password. Asking twice
      // meant two prompts before the app had drawn anything, which is what
      // made RadioPod unusable on macOS while todopod only prompted at login.

      provider.setLoggedIn(loggedIn);

      if (loggedIn) {
        if (!mounted) return;
        await getKeyFromUserIfRequired(context, widget);
        if (!mounted) return;
      }

      provider.setStartupPhase(StartupPhase.loading);
      await provider.load();
    } on Exception catch (e) {
      debugPrint('[AppScaffold] key/load error: $e');
    } finally {
      provider.setStartupPhase(StartupPhase.ready);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only rebuild this scaffold when isKeySaved itself changes — not on every
    // AppProvider notify, which happens on loads, edits and imports.

    return Selector<AppProvider, bool>(
      selector: (_, p) => p.isKeySaved,
      builder: (context, isKeySaved, _) => ValueListenableBuilder<bool>(
        valueListenable: CaptionService.instance.active,
        builder: (context, captionsOn, _) => StreamBuilder<Station?>(
          stream: _station,
          builder: (context, station) => _scaffold(
            context,
            isKeySaved: isKeySaved,
            captionsOn: captionsOn,
            station: station.data,
          ),
        ),
      ),
    );
  }

  /// The CC button.
  ///
  /// GREYED OUT, NOT HIDDEN, for a station in a language captions cannot
  /// do. Hiding it would make the button come and go as the listener moves
  /// between stations, with no clue why; greyed, it stays in its place and
  /// its tooltip, or a tap, says what is missing. SolidAppBarAction has no
  /// disabled state, so the grey is the theme's disabled colour and the tap
  /// only explains.

  SolidAppBarAction _captionsAction(
    BuildContext context, {
    required bool captionsOn,
    required Station? station,
  }) {
    final model = speechModelFor(station);
    final language = station?.language?.trim() ?? '';

    return SolidAppBarAction(
      id: 'captions',
      icon: captionsOn
          ? Icons.closed_caption
          : Icons.closed_caption_off_outlined,
      visible: CaptionService.instance.supported && station != null,
      color: model == null
          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
          : null,
      tooltip: model == null
          ? '''

              **Live captions unavailable**

              Captions are available for stations that broadcast in English
              or Chinese. ${language.isEmpty ? 'This station does not say what language it is in.' : 'This station is listed as $language.'}

              '''
          : captionsOn
          ? '''

              **Captions are on**

              Tap to turn them off.

              '''
          : '''

              **Live captions**

              Show what is being said on the station, transcribed on this
              device as you listen. Nothing is sent anywhere to be
              transcribed.

              The words also replace the station name on the lock screen,
              with the station and programme on the line below.

              This station uses the ${model.language} speech model, of
              ${model.sizeLabel}, which is downloaded the first time.

              ''',
      onPressed: () => model == null
          ? showCaptionsUnavailable(context, station)
          : toggleCaptions(context),
    );
  }

  Widget _scaffold(
    BuildContext context, {
    required bool isKeySaved,
    required bool captionsOn,
    required Station? station,
  }) => SolidScaffold(
    aboutConfig: SolidAboutConfig(
      applicationName: appName,
      applicationIcon: Image.asset(
        'assets/images/app_icon.png',
        width: 64,
        height: 64,
      ),
      applicationLegalese: '''

          © 2026 Togaware Pty Ltd

          ''',
      text: '''

          RadioPod plays internet radio and keeps your station library and
          playlists encrypted in your personal Solid Pod, so your listening
          stays under your control. Your Solid Pod can be hosted on any Solid
          server and, being encrypted, your data is protected against casual
          access by anyone, including the server administrators.

          ### Key features

          - Search the community-run Radio-Browser station database
          - Save stations and group them into playlists
          - Import and export M3U and PLS playlist files
          - Android Auto support for browsing and playing while driving
          - Background playback with lock screen and headset controls
          - Live captions for English and Chinese stations, recognised on the
            device, on iOS and macOS
          - Runs on Android, iOS, Linux, macOS, Windows and the web
          - Security key management for encrypted data
          - Theme switching (light / dark / system)

          ### Privacy

          RadioPod collects nothing and reports nothing. The only third party
          it contacts is Radio-Browser, and only when you search — the search
          text and an app name are all that are sent. Live captions, when you
          first switch them on, download a speech model; recognition then
          happens on your device. RadioPod deliberately
          does not call the Radio-Browser click-reporting endpoint, so no
          record of what you listen to leaves your device. Your stations,
          playlists and listening are never shared.

          For more information, visit the
          [RadioPod](https://github.com/gjwgit/radiopod) GitHub repository and
          our [Australian Solid Community](https://solidcommunity.au) web site.

          ''',
      docsUrl: 'https://gjwgit.github.io/radiopod',
    ),
    themeToggle: const SolidThemeToggleConfig(enabled: true),
    appBar: SolidAppBarConfig(
      title: appName,
      versionConfig: const SolidVersionConfig(
        changelogUrl:
            'https://github.com/gjwgit/radiopod/blob/dev/CHANGELOG.md',
      ),
      actions: [
        // Captions belong to what is playing, not to any one screen, so
        // the button lives in the app bar that every screen shares, and
        // appears once a station has been started. The rows are already
        // full — logo, name, song, and a trailing action that differs by
        // screen — and a button on the playing row would vanish the
        // moment the list scrolled it away.

        _captionsAction(context, captionsOn: captionsOn, station: station),

        // 20260925 gjw Hidden with `visible` rather than left out of the
        // list, as SolidAppBarAction documents: that keeps its id
        // registered, so it returns to its place in the user's own
        // ordering instead of jumping to the end when it reappears.
        SolidAppBarAction(
          id: 'new-station',
          icon: Icons.add,
          visible: _tab == _stationsTab,
          tooltip: '''

              **New station**

              Add a station manually, specifically for a station that
              Radio-Browser does not list.

              You will give it a name, the stream address, and optionally a
              logo. It is saved to your library only: nothing is submitted to
              Radio-Browser or anywhere else.

              ''',
          onPressed: _newStation,
        ),
        buildPodRefreshAction(
          context: context,
          onRefresh: context.read<AppProvider>().refreshFromPod,
        ),
      ],
    ),
    onMenuSelected: (i) => setState(() => _tab = i),
    menu: [
      const SolidMenuItem(
        title: 'Stations',
        icon: Icons.radio,
        tooltip:
            '**Stations**\n\n'
            'Every station you have saved. Tap one to start listening.\n\n'
            'Drag a station by the grip on the right to put the list in '
            'the order you want. That order is saved, and is the order '
            'the car and an export see. Dragging is unavailable while '
            'the filter box has something in it.',
        child: CaptionArea(child: StationsScreen()),
      ),
      const SolidMenuItem(
        title: 'Search',
        icon: Icons.search,
        tooltip:
            '**Search**\n\n'
            'Find stations in the community-run Radio-Browser database '
            'and save the ones you like. Only your search text is sent.',
        child: CaptionArea(child: SearchScreen()),
      ),
      const SolidMenuItem(
        title: 'Playlists',
        icon: Icons.queue_music,
        tooltip:
            '**Playlists**\n\n'
            'Group your stations into named lists. Playlists are the '
            'folders Android Auto shows you while driving.',
        child: CaptionArea(child: PlaylistsScreen()),
      ),
      const SolidMenuItem(
        title: 'Export/Import',
        icon: Icons.save_alt,
        tooltip:
            '**Export/Import**\n\n'
            'Export and import playlists in the open M3U and PLS formats.',
        child: CaptionArea(child: TransferScreen()),
      ),
      const SolidMenuItem(
        title: 'Settings',
        icon: Icons.settings,
        tooltip:
            '**Settings**\n\n'
            'Privacy, the offline station cache and preferences.',
        child: CaptionArea(child: SettingsScreen()),
      ),
    ],

    statusBar: SolidStatusBarConfig(
      loginStatus: const SolidLoginStatus(),
      serverInfo: const SolidServerInfo(
        serverUri: SolidConfig.defaultServerUrl,
      ),
      securityKeyStatus: SolidSecurityKeyStatus(
        isKeySaved: isKeySaved,
        title: 'RadioPod Security Keys',
        tooltip:
            '**Security Keys**\n\n'
            'Manage your Solid Pod encryption key.\n'
            'Tap to view, change or forget the key.',
        onKeyStatusChanged: (hasKey) {
          final provider = context.read<AppProvider>();
          final wasKeySaved = provider.isKeySaved;
          provider.setKeySaved(hasKey);
          if (hasKey && !wasKeySaved) {
            // A key appearing means the user has just logged in and
            // unlocked, so the library may have moved from the device to
            // the Pod. This is the one place re-asking solidpod is worth
            // its keychain access, because the answer has genuinely
            // changed and the user is already in a login flow.

            provider.resolveSource().then((_) => provider.load());
          }
        },
      ),
    ),
  );
}
