/// Fill in a hand-added station's details from Radio-Browser.
///
// Time-stamp: <Wednesday 2026-10-14 10:00:00 +1100 Graham Williams>
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

import 'package:flutter/foundation.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/radio_browser.dart';

/// [current] with the facts from Radio-Browser's record [found] beneath it.
///
/// What the listener typed or chose stays theirs: the name, the address,
/// the picture, the reconnect setting, and the local id that playlists
/// hold. Everything else — country, language, codec, bitrate, tags, the
/// Radio-Browser id — comes from the record. Pure, so it can be tested
/// without a network.

Station withRadioBrowserDetails(Station current, Station found) =>
    found.copyWith(
      id: current.id,
      name: current.name,
      url: current.url,
      icon: current.icon,
      reconnectOnEnd: current.reconnectOnEnd,
    );

/// Look up the station [id] by its address and save what Radio-Browser
/// knows about it.
///
/// 20261014 gjw Run AFTER the station is saved, not inside the New station
/// dialog: the dialog deliberately makes no network round trip, and adding
/// a station must not wait on, or fail because of, a third party. A miss or
/// a network failure just leaves the station as it was typed. The station
/// is read again after the lookup so an edit or delete made meanwhile wins.

Future<void> fillFromRadioBrowser(AppProvider provider, String id) async {
  final before = provider.stations.where((s) => s.id == id).firstOrNull;
  if (before == null || before.stationUuid != null) return;

  try {
    final found = await RadioBrowser.byUrl(before.url);
    final current = provider.stations.where((s) => s.id == id).firstOrNull;
    if (found == null || current == null) return;

    await provider.updateStation(withRadioBrowserDetails(current, found));
  } catch (e) {
    debugPrint('[StationLookup] no details for ${before.url}: $e');
  }
}
