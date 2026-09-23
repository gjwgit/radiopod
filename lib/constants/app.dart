/// RadioPod - app-wide constants.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
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
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams

library;

import 'package:flutter/material.dart';

/// Application name displayed in the UI.

const appName = 'RadioPod';

/// Application title displayed as the window title.

const String appTitle = 'RadioPod - Listen to Internet Radio';

/// App directory name used by solidpod for storage paths.

const appDirectory = 'radiopod';

/// Pod filename for the saved station library (relative to app directory).

const stationsFileName = 'stations.ttl';

/// Pod filename for the named playlists (relative to app directory).

const playlistsFileName = 'playlists.ttl';

/// Notification channel identity for the Android media notification.
///
/// Also the channel Android Auto surfaces the app under, so it must be
/// stable across releases.

const notificationChannelId = 'com.togaware.radiopod.channel.audio';
const notificationChannelName = 'Radio playback';

/// Root of the Android Auto browse tree, and the ids of its two branches.
///
/// Android Auto asks the handler for the children of [browseRootId] and then
/// drills into whichever branch the driver taps. Playlist branches append
/// the playlist id to [browsePlaylistPrefix].

const browseRootId = 'root';
const browseAllStationsId = 'all_stations';
const browsePlaylistPrefix = 'playlist:';

/// How Android Auto should draw a level of the browse tree.
///
/// A LIST puts one station per row with its name in full and scrolls; a GRID
/// shows tiles of station logos. RadioPod asks for a list, because most
/// stations have no logo at all — Radio-Browser's favicon field is empty or
/// dead for a good share of them — so a grid becomes rows of identical
/// placeholder tiles with the names truncated underneath.

const autoStyleList = 1;
const autoStyleGrid = 2;

/// SnackBar colours.
///
/// Deliberately understated: a soft pastel BAR carrying near-black text,
/// rather than a saturated theme colour. Tune these to restyle every
/// SnackBar. A negative/orange bar colour goes here when one is first needed.

const snackBarPositive = Color(0xFFC8E6C9); // green.shade100 — bar colour
const snackBarInk = Color(0xFF1B1B1B); // near-black text on a pastel bar

/// How long a SnackBar stays on screen.
///
/// One standard time for every message, matching Flutter's own default.
/// Do NOT extend it for an Undo action — the button rides along for the
/// standard time and then the bar gets out of the way.

const snackBarDuration = Duration(seconds: 4);

/// Surface and text for a SnackBar with no positive or negative sense, e.g.
/// one built directly rather than through app_snack_bar.dart.

const snackBarSurface = Color(0xFF212121); // grey.shade900
const snackBarNeutral = Color(0xFFE0E0E0); // grey.shade300

/// Seed colour for the Material 3 scheme — a warm radio-dial amber.

const seedColour = Color(0xFFB4632A);
