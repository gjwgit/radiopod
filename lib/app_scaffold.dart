/// RadioPod — application scaffold configuration.
///
// Time-stamp: <Wednesday 2026-09-23 13:43:29 +1000 Graham Williams>
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
import 'package:radiopod/screens/playlists_screen.dart';
import 'package:radiopod/screens/search_screen.dart';
import 'package:radiopod/screens/settings_screen.dart';
import 'package:radiopod/screens/stations_screen.dart';
import 'package:radiopod/screens/transfer_screen.dart';
import 'package:radiopod/services/app_provider.dart'
    show AppProvider, StartupPhase;
import 'package:radiopod/widgets/player_bar.dart';
import 'package:radiopod/widgets/pod_refresh_action.dart';

const appScaffold = AppScaffold();

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
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
      builder: (context, isKeySaved, _) => SolidScaffold(
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
          - Runs on Android, iOS, Linux, macOS, Windows and the web
          - Security key management for encrypted data
          - Theme switching (light / dark / system)

          ### Privacy

          RadioPod collects nothing and reports nothing. The only third party
          it contacts is Radio-Browser, and only when you search — the search
          text and an app name are all that are sent. RadioPod deliberately
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
            buildPodRefreshAction(
              context: context,
              onRefresh: context.read<AppProvider>().refreshFromPod,
            ),
          ],
        ),
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
            child: StationsScreen(),
          ),
          const SolidMenuItem(
            title: 'Search',
            icon: Icons.search,
            tooltip:
                '**Search**\n\n'
                'Find stations in the community-run Radio-Browser database '
                'and save the ones you like. Only your search text is sent.',
            child: SearchScreen(),
          ),
          const SolidMenuItem(
            title: 'Playlists',
            icon: Icons.queue_music,
            tooltip:
                '**Playlists**\n\n'
                'Group your stations into named lists. Playlists are the '
                'folders Android Auto shows you while driving.',
            child: PlaylistsScreen(),
          ),
          const SolidMenuItem(
            title: 'Export/Import',
            icon: Icons.save_alt,
            tooltip:
                '**Export/Import**\n\n'
                'Export and import playlists in the open M3U and PLS formats.',
            child: TransferScreen(),
          ),
          const SolidMenuItem(
            title: 'Settings',
            icon: Icons.settings,
            tooltip:
                '**Settings**\n\n'
                'Privacy, the offline station cache and preferences.',
            child: SettingsScreen(),
          ),
        ],

        // 20260921 gjw The now-playing bar rides in the Scaffold's persistent
        // bottomSheet slot so it is visible from every screen — switching to
        // Search must not hide what is playing or take away the Stop button.
        // PlayerBar collapses to nothing when there is no current station, so
        // the slot costs no space when idle.
        bottomSheet: const PlayerBar(),
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
      ),
    );
  }
}
