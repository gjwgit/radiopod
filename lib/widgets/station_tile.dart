/// StationTile — one station in a list, and its transport control.
///
// Time-stamp: <Wednesday 2026-09-23 06:00:00 +1000 Graham Williams>
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

import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/station_icon.dart';

/// A station row, used by the Stations list, a playlist's contents, and the
/// Search results.
///
/// THE ROW IS THE PLAYER. There is no separate now-playing bar: the station
/// on air is the highlighted row, and its second line leads with what the
/// transport is doing — `Playing | <song or details>`, `Paused`, `Stopped`,
/// `Connecting`, `Loading` or `Unavailable`. Tapping the row starts a
/// station, or stops the one playing. Only the current station carries a
/// status, so starting another moves the label to the new row.
///
/// A floating bar was tried first and sat over the last entry in the list,
/// hiding it. Putting the state in the row removes the overlap, saves the
/// screen space, and means a station previewed from Search — which is in no
/// list of saved stations — can still be stopped from where it was started.
///
/// THE LOGO STAYS. An earlier version swapped the row's logo for a Stop
/// button while it played, which hid the one picture that identifies the
/// station at a glance. The status label says the same thing in words.
///
/// The trailing widget is supplied by the caller because the useful action
/// differs by screen: an overflow menu in the library, a remove button
/// inside a playlist, a save button in Search.

class StationTile extends StatelessWidget {
  final Station station;

  /// True when this station is the one the media session is on, whatever the
  /// transport is doing. Drives the highlight and the status label.

  final bool current;

  final bool playing;
  final bool connecting;
  final bool loading;
  final bool paused;
  final bool failed;

  /// The song on air, shown INSTEAD of the station details while it is
  /// known. Most streams announce nothing, so the details remain the common
  /// case rather than a fallback.

  final String? track;

  final VoidCallback? onTap;
  final Widget? trailing;

  const StationTile({
    super.key,
    required this.station,
    this.current = false,
    this.playing = false,
    this.connecting = false,
    this.loading = false,
    this.paused = false,
    this.failed = false,
    this.track,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = current ? _status() : null;
    final detail = _detail();
    final showsTrack = current && playing && track != null;

    final detailStyle = TextStyle(
      color: failed && current
          ? cs.error
          : showsTrack
          ? cs.primary
          : cs.onSurfaceVariant,
      fontWeight: showsTrack ? FontWeight.w500 : FontWeight.w400,
    );

    return ListTile(
      selected: current,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.38),
      leading: _logo(cs),
      title: Text(
        station.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: current ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: status == null && detail == null
          ? null
          : Text.rich(
              TextSpan(
                children: [
                  if (status != null)
                    TextSpan(
                      text: status,
                      style: TextStyle(
                        color: failed ? cs.error : cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (status != null && detail != null)
                    TextSpan(
                      text: ' | ',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  if (detail != null)
                    TextSpan(text: detail, style: detailStyle),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// What the transport is doing on the current station, as one word.
  ///
  /// Checked in order of what matters most: a failure outranks everything,
  /// and a buffering stream is Loading even though the player still counts
  /// it as playing.

  String _status() {
    if (failed) return 'Unavailable';
    if (connecting) return 'Connecting';
    if (loading) return 'Loading';
    if (playing) return 'Playing';
    if (paused) return 'Paused';
    return 'Stopped';
  }

  /// The text after the status: the reason for a failure, the song on air,
  /// or the station's own details.

  String? _detail() {
    if (current) {
      if (failed) return 'Could not connect to this station.';
      if (playing && track != null) return track;
    }

    return station.subtitle.isEmpty ? null : station.subtitle;
  }

  /// The station logo, falling back to a radio icon.
  ///
  /// Station logos are arbitrary URLs from Radio-Browser and a good number of
  /// them are dead or not images at all, so a load failure has to be ordinary
  /// rather than an error — [Image.network] gets an errorBuilder and the icon
  /// takes over silently.

  Widget _logo(ColorScheme cs) {
    final fallback = Icon(Icons.radio, color: cs.primary);

    // A stored icon wins: it was chosen or downloaded deliberately, it
    // cannot rot the way the advertised URL does, and it needs no network.

    final stored = decodeStationIcon(station.icon);
    if (stored != null) {
      return _framed(
        Image.memory(stored, fit: BoxFit.cover, gaplessPlayback: true),
      );
    }

    final favicon = station.favicon;
    if (favicon == null || favicon.isEmpty) return fallback;

    return _framed(
      Image.network(
        favicon,
        fit: BoxFit.cover,
        // 20260924 gjw CORS. On the web the default strategy fetches the
        // BYTES of the image, which the browser refuses cross-origin unless
        // the server sends Access-Control-Allow-Origin. Station artwork is
        // an arbitrary third-party URL and essentially never does — none of
        // ABC News Radio's five Radio-Browser entries do — so every logo
        // fell back to the radio glyph in the browser while looking right
        // on every other platform.
        //
        // `fallback` keeps the byte fetch, which is what allows the image to
        // be clipped and blended normally, and drops to an <img> element in
        // a platform view only when that fetch fails. An <img> merely
        // DISPLAYS a cross-origin image, which browsers have always allowed;
        // it is reading the pixels back that needs permission.
        //
        // Ignored off the web, so this costs the other platforms nothing.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _framed(Widget child) => SizedBox(
    width: 40,
    height: 40,
    child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
  );
}
