/// StationTile — one station in a list, and its transport control.
///
// Time-stamp: <Wednesday 2026-09-23 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:flutter/material.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/station_icon.dart';

/// A station row, used by the Stations list, a playlist's contents, and the
/// Search results.
///
/// THE ROW IS THE PLAYER. There is no separate now-playing bar: the station
/// on air is the highlighted row, its leading logo becomes a Stop button,
/// and its second line carries the song rather than the station's codec and
/// bitrate. Tapping the row starts a station, or stops the one playing.
///
/// A floating bar was tried first and sat over the last entry in the list,
/// hiding it. Putting the state in the row removes the overlap, saves the
/// screen space, and means a station previewed from Search — which is in no
/// list of saved stations — can still be stopped from where it was started.
///
/// The trailing widget is supplied by the caller because the useful action
/// differs by screen: an overflow menu in the library, a remove button
/// inside a playlist, a save button in Search.

class StationTile extends StatelessWidget {
  final Station station;

  /// True when this station is the one the media session is on, whatever the
  /// transport is doing. Drives the highlight and the leading control.

  final bool current;

  final bool playing;
  final bool connecting;
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
    this.failed = false,
    this.track,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final second = _secondLine();

    return ListTile(
      selected: current,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.38),
      leading: _leading(cs),
      title: Text(
        station.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: current ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: second == null
          ? null
          : Text(
              second,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: failed
                    ? cs.error
                    : (current && track != null)
                    ? cs.primary
                    : cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: (current && track != null)
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// The second line: what is happening on the current station, the song it
  /// announced, or the station's own details.

  String? _secondLine() {
    if (current) {
      if (failed) return 'Could not connect to this station.';
      if (connecting) return 'Connecting…';
      if (track != null) return track;
      if (!playing) return 'Stopped';
    }

    return station.subtitle.isEmpty ? null : station.subtitle;
  }

  /// The station logo, or the transport control when this row is on air.
  ///
  /// Swapping the logo for a Stop button is deliberate: it puts the control
  /// exactly where the eye already is for the highlighted row, and costs no
  /// extra width in a list that has to work on a phone.

  Widget _leading(ColorScheme cs) {
    if (current) {
      if (connecting) {
        return const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }

      return SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          failed
              ? Icons.error_outline
              : playing
              ? Icons.stop_circle
              : Icons.play_circle,
          size: 34,
          color: failed ? cs.error : cs.primary,
        ),
      );
    }

    return _logo(cs);
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
      return _framed(Image.memory(stored, fit: BoxFit.cover));
    }

    final favicon = station.favicon;
    if (favicon == null || favicon.isEmpty) return fallback;

    return _framed(
      Image.network(
        favicon,
        fit: BoxFit.cover,
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
