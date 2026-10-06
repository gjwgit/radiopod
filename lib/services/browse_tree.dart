/// Browse tree — the station hierarchy Android Auto and CarPlay present.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
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

import 'package:audio_service/audio_service.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/station_icon_cache.dart';

/// The two levels of the browse tree, built as plain functions over the
/// library so the audio handler stays about playback.
///
/// The head unit asks for the children of [browseRootId] and gets a folder
/// per playlist plus an "All Stations" folder; asking for the children of a
/// folder gets playable stations. Two levels is the most a driver should ever
/// have to tap through, which is also what Android's media app quality
/// guidelines ask for.

/// Media id of a playable station, qualified by the folder it was reached
/// through.
///
/// Android Auto hands back only the media id when the driver taps a station,
/// with no indication of where they were browsing. Encoding the parent folder
/// in the id means the handler can set the queue to the surrounding playlist,
/// so Next and Previous on the steering wheel move through the stations the
/// driver was actually looking at rather than through the whole library.

String stationMediaId(String parentId, String stationId) =>
    '$parentId/$stationId';

/// Split a media id built by [stationMediaId] back into its two parts.
///
/// Returns null for a folder id, which has no separator. The station id is
/// taken from the LAST separator so a playlist id containing a slash could
/// never shift the split.

({String parentId, String stationId})? splitStationMediaId(String mediaId) {
  final i = mediaId.lastIndexOf('/');
  if (i <= 0 || i == mediaId.length - 1) return null;

  return (
    parentId: mediaId.substring(0, i),
    stationId: mediaId.substring(i + 1),
  );
}

/// The top level: all stations, then every playlist.
///
/// ALL STATIONS COMES FIRST ON PURPOSE. Android Auto turns the root's
/// browsable children into the tabs across the top of the screen and opens
/// the first one, so putting the station list there means the driver lands
/// straight on a scrollable list of stations instead of having to drill into
/// a folder. The playlists become the remaining tabs.
///
/// This also reads better now the Stations screen is in the user's own
/// dragged order rather than alphabetical: whatever they reach for most sits
/// at the top of the list the car opens with.
///
/// Empty playlists are still listed — hiding them would make a playlist the
/// user just created appear broken.

List<MediaItem> browseRoot(List<Playlist> playlists) => [
  const MediaItem(
    id: browseAllStationsId,
    title: 'All Stations',
    playable: false,
  ),
  for (final p in playlists)
    MediaItem(
      id: '$browsePlaylistPrefix${p.id}',
      title: p.name,
      playable: false,
      displaySubtitle: _stationCount(p.stationIds.length),
    ),
];

/// The stations inside the folder [parentId].
///
/// An unknown parent yields an empty list rather than an error: a head unit
/// can ask for a folder that has since been deleted, and an empty folder is
/// the honest answer.

List<MediaItem> browseChildren(
  String parentId,
  List<Station> stations,
  List<Playlist> playlists,
) {
  if (parentId == browseRootId) return browseRoot(playlists);

  // 20260922 gjw Library order, NOT alphabetical. The user arranges the
  // Stations screen by dragging, and that arrangement is the point — the
  // stations they reach for most go at the top, which is exactly what a
  // driver wants first in the car. Re-sorting here would throw that away.

  if (parentId == browseAllStationsId) {
    return [for (final s in stations) stationMediaItem(s, parentId)];
  }

  if (!parentId.startsWith(browsePlaylistPrefix)) return [];

  final playlistId = parentId.substring(browsePlaylistPrefix.length);
  final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
  if (playlist == null) return [];

  // Keep the playlist's own order, and skip any id whose station has since
  // been deleted from the library rather than showing a blank row.

  final byId = {for (final s in stations) s.id: s};

  return [
    for (final id in playlist.stationIds)
      if (byId[id] != null) stationMediaItem(byId[id]!, parentId),
  ];
}

/// One playable station, as reached through the folder [parentId].
///
/// [track] is the song currently on air, as announced by the stream's ICY
/// metadata. When it is known it takes the subtitle slot, because what is
/// playing right now is more use to a listener than the station's codec and
/// bitrate; the station details stand in whenever it is not. The track is
/// also carried in extras so the UI can tell the two apart.

MediaItem stationMediaItem(Station station, String parentId, {String? track}) =>
    MediaItem(
      id: stationMediaId(parentId, station.id),
      title: station.name,
      artist: track ?? (station.subtitle.isEmpty ? null : station.subtitle),
      album: appName,
      artUri: sessionArtUri(station),
      playable: true,
      isLive: true,
      extras: {'stationId': station.id, 'track': ?track},
    );

/// The station's OWN logo, as Radio-Browser gave it, or null.
///
/// Only http and https pass. The value comes out of Pod data and could be
/// anything; an odd scheme should not reach the media session, and a head
/// unit would not fetch it anyway.
///
/// This is the FALLBACK. What a station actually shows is [sessionArtUri],
/// which prefers a picture the user chose.

Uri? _artUri(Station station) {
  final favicon = station.favicon;
  if (favicon == null || favicon.isEmpty) return null;
  final uri = Uri.tryParse(favicon);
  if (uri == null || !uri.hasScheme) return null;

  return (uri.isScheme('http') || uri.isScheme('https')) ? uri : null;
}

/// Artwork for a station: the picture the user chose if there is one,
/// otherwise the station's own logo.
///
/// 20261005 gjw THE USER'S CHOICE WINS. They went out of their way to pick
/// it, usually because the station's own logo was missing or wrong, so
/// preferring the logo would undo the very thing they did.
///
/// 20261006 gjw THIS IS NOW ONE RULE FOR EVERY SURFACE, which it could not
/// be while a chosen icon was a file:// URI.
///
/// A browse row and the NARROW now-playing card beside the map carry only a
/// URI: audio_service builds a MediaDescriptionCompat with setIconUri
/// (AudioServicePlugin.java:1174) and ANDROID AUTO'S OWN PROCESS fetches it.
/// It cannot read our app-private files, so a chosen icon was blank on both
/// while an https station logo was not. Only the WIDE now-playing view
/// worked, because that one draws the bitmap audio_service loads in our
/// process (AudioService.java:811).
///
/// That is why this was split in two for a day: preferring the chosen icon
/// everywhere made the car's list WORSE than before the feature existed, a
/// station with both an icon and a logo going from showing the logo to
/// showing nothing. StationIconProvider removes the reason for the split by
/// serving the icons to Auto as content://, readable across processes —
/// see StationIconCache.uriFor.

Uri? sessionArtUri(Station station) =>
    StationIconCache.uriFor(station.id) ?? _artUri(station);

String _stationCount(int n) => '$n station${n == 1 ? '' : 's'}';
