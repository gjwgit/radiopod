/// RadioPod — main entry for the app.
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
import 'package:solidui/solidui.dart';
import 'package:window_manager/window_manager.dart';

import 'package:radiopod/app.dart';
import 'package:radiopod/constants/app.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/player.dart';

void main() async {
  // 20260921 gjw We want to ensure Flutter bindings are initialised for async
  // operations, particularly to set the Linux desktop window [title] as we do
  // below.

  WidgetsFlutterBinding.ensureInitialized();
  SolidSecurityKeyCentralManager.instance;

  // 20260921 gjw Start the media session BEFORE runApp. On Android the system
  // can launch this app headless — Android Auto starts the MediaBrowserService
  // on its own, with no UI — and the browse tree has to answer the head unit
  // straight away. Player.init() also loads the cached station library so the
  // car has something to show before any Pod login has happened. On Linux and
  // Windows audio_service falls back to its no-op platform implementation, so
  // this is safe everywhere: playback works, only the OS-level media controls
  // are absent.

  await Player.init();

  if (isDesktop) {
    await windowManager.ensureInitialized();

    // 20260921 gjw For our desktop app we tune various window oriented
    // settings. Shown through solidui, which opens the window at the size it
    // was last left at and keeps that size up to date as it is resized. The
    // user sets the size, and turns remembering it off, under Settings in the
    // profile menu. Until a size has been remembered the window opens at the
    // default in `linux/my_application.cc`.

    await SolidWindowSize.show(
      const WindowOptions(
        title: appTitle,
        minimumSize: Size(500, 800),
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      ),
    );
  }

  // 20260921 gjw The runApp() function takes the given Widget and makes it the
  // root of the widget tree. AppProvider is provided here so the entire tree
  // (App -> AppScaffold -> screens) can read and watch it.

  runApp(
    ChangeNotifierProvider(create: (_) => AppProvider(), child: const App()),
  );
}
