/// RadioPod — the primary [MaterialApp] widget.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License").
///
/// License: https://opensource.org/license/gpl-3-0.
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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:solidui/solidui.dart';

import 'package:radiopod/app_scaffold.dart';
import 'package:radiopod/constants/app.dart';

// 20260921 gjw This widget is the root of the application. On startup it will
// call upon [SolidLogin] to connect to the user's Pod stored within the user's
// data vault on their chosen Solid server.

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return SolidThemeApp(
      // 20260921 gjw We can manually turn off the debug banner. It is turned
      // off automatically for a `flutter --release`.
      //
      debugShowCheckedModeBanner: true,

      title: appTitle,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColour),
        useMaterial3: true,

        // 20260921 gjw Understated SnackBars: floating, rounded, and quiet.
        // This is the neutral fallback for a SnackBar built directly; the
        // helper in lib/widgets/app_snack_bar.dart overrides the background
        // with a soft green bar.

        snackBarTheme: const SnackBarThemeData(
          backgroundColor: snackBarSurface,
          contentTextStyle: TextStyle(color: snackBarNeutral, fontSize: 14),
          behavior: SnackBarBehavior.floating,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),

      // 20260921 gjw Login is NOT required to reach the app. Playback of an
      // already-cached station must work in the car without a login prompt,
      // and the library only needs the Pod when it is read or written.

      home: SolidLogin(
        required: false,
        appDirectory: appDirectory,
        title: appTitle.replaceAll(' - ', '\n'),
        image: const AssetImage('assets/images/app_image.jpg'),
        logo: const AssetImage('assets/images/app_icon.png'),
        link: 'https://github.com/gjwgit/radiopod',
        clientId: 'https://gjwgit.github.io/radiopod/client-profile.jsonld',
        redirectUris: kIsWeb
            ? ['${Uri.base.origin}/redirect.html']
            : const [
                'com.togaware.radiopod://redirect',
                'http://localhost:4400/redirect.html',
              ],
        // 20260921 gjw Mounted here, inside the MaterialApp, so a Navigator
        // exists for the dialog and the listener outlives individual screens.
        // It reports Pod writes that nothing awaits — saving a station found
        // in Search, say — which would otherwise fail silently.

        child: const SolidWriteFailureListener(child: appScaffold),
      ),
    );
  }
}
