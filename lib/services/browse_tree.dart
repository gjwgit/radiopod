/// Browse tree — the station hierarchy Android Auto and CarPlay present.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:audio_service/audio_service.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';

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

/// The top level: every playlist, then all stations.
///
/// Playlists come first because they are the lists the user curated, and a
/// long alphabetical dump of every station is rarely what is wanted while
/// driving. Empty playlists are still listed — hiding them would make a
/// playlist the user just created appear broken.

List<MediaItem> browseRoot(List<Playlist> playlists) => [
  for (final p in playlists)
    MediaItem(
      id: '$browsePlaylistPrefix${p.id}',
      title: p.name,
      playable: false,
      displaySubtitle: _stationCount(p.stationIds.length),
    ),
  const MediaItem(
    id: browseAllStationsId,
    title: 'All Stations',
    playable: false,
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
      artUri: _artUri(station.favicon),
      playable: true,
      isLive: true,
      extras: {'stationId': station.id, 'track': ?track},
    );

/// A station logo URL as a [Uri], or null when there is none or it will not
/// parse. Only http(s) is accepted — a head unit will not fetch anything
/// else, and an odd scheme in Pod data should not reach the media session.

Uri? _artUri(String? favicon) {
  if (favicon == null || favicon.isEmpty) return null;
  final uri = Uri.tryParse(favicon);
  if (uri == null || !uri.hasScheme) return null;

  return (uri.isScheme('http') || uri.isScheme('https')) ? uri : null;
}

String _stationCount(int n) => '$n station${n == 1 ? '' : 's'}';
