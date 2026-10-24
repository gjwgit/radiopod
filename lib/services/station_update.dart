/// Bring a saved station's or podcast's details up to date.
///
// Time-stamp: <Saturday 2026-10-17 10:00:00 +1100 Graham Williams>
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

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/podcast_feed.dart';
import 'package:radiopod/services/radio_browser.dart';
import 'package:radiopod/services/station_lookup.dart';

/// What a freshly fetched record becomes once the listener's own choices
/// are laid back over it.
///
/// Radio-Browser owns the facts — the address, the codec, where the station
/// broadcasts from. The listener owns three things that a refresh must never
/// touch:
///
/// - the local [Station.id], which playlists reference; replacing it would
///   silently drop the station out of every playlist holding it,
/// - [Station.reconnectOnEnd], which answers a question about this listener's
///   experience that the database has no opinion on,
/// - [Station.icon], a picture they went out of their way to choose.
///
/// Pure, so the rule can be tested without a network.

Station applyRefresh(
  Station fresh,
  Station current, {
  required bool reconnectOnEnd,
  required String? icon,
}) =>
    fresh.copyWith(id: current.id, reconnectOnEnd: reconnectOnEnd, icon: icon);

/// What an update found: the station with its new details, or null when
/// nothing was found; a name to offer in the Name field, when the source
/// has one; and a sentence to show beneath the button.

typedef StationUpdate = ({Station? station, String? name, String message});

/// Fetch [current]'s details again from wherever they came from.
///
/// 20261017 gjw One entry point for the Properties dialog's Update button,
/// which used to name Radio-Browser and so read wrongly on a podcast. A
/// station from Search is looked up by its Radio-Browser id, one added by
/// hand by its address, and a podcast from its own feed. The listener's
/// choices — reconnect and picture — are laid back over whatever arrives.
///
/// Throws on a network failure, so the caller can say it could not reach
/// the source.

Future<StationUpdate> updateStationDetails(
  Station current, {
  required bool reconnectOnEnd,
  required String? icon,
}) async {
  if (current.isPodcast) {
    final feed = await fetchFeed(current.url);

    return (
      station: current.copyWith(
        author: feed.author ?? current.author,
        favicon: feed.image ?? current.favicon,
        homepage: feed.homepage ?? current.homepage,
        description: feed.description ?? current.description,
        reconnectOnEnd: reconnectOnEnd,
        icon: icon,
      ),
      name: feed.title,
      message: 'Updated from the podcast\'s feed. Save to keep it.',
    );
  }

  final uuid = current.stationUuid;
  if (uuid != null) {
    final fresh = await RadioBrowser.lookup(uuid);
    if (fresh == null) {
      return (
        station: null,
        name: null,
        message:
            'Radio-Browser no longer lists this station. Entries are '
            'removed when they stop working.',
      );
    }

    return (
      station: applyRefresh(
        fresh,
        current,
        reconnectOnEnd: reconnectOnEnd,
        icon: icon,
      ),
      name: fresh.name,
      message: 'Updated from Radio-Browser. Save to keep it.',
    );
  }

  // A station with no Radio-Browser id is found by its address, and then
  // keeps its address and name: the address is how it was found, and the
  // name was typed by the listener.

  final found = await RadioBrowser.byUrl(current.url);
  if (found == null) {
    return (
      station: null,
      name: null,
      message: 'Radio-Browser has no station at this address.',
    );
  }

  return (
    station: withRadioBrowserDetails(
      current,
      found,
    ).copyWith(reconnectOnEnd: reconnectOnEnd, icon: icon),
    name: null,
    message: 'Updated from Radio-Browser. Save to keep it.',
  );
}
