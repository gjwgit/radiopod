/// StationTile — one station in a list.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:flutter/material.dart';

import 'package:radiopod/models/station.dart';

/// A station row, used by both the Stations list and a playlist's contents.
///
/// The trailing widget is supplied by the caller because the useful action
/// differs by screen — a remove button inside a playlist, an overflow menu in
/// the library — while the leading logo, the title and the subtitle should
/// look identical everywhere.

class StationTile extends StatelessWidget {
  final Station station;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const StationTile({
    super.key,
    required this.station,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      selected: selected,
      leading: _logo(cs),
      title: Text(
        station.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: station.subtitle.isEmpty
          ? null
          : Text(
              station.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// The station logo, falling back to a radio icon.
  ///
  /// Station logos are arbitrary URLs from Radio-Browser and a good number of
  /// them are dead or not images at all, so a load failure has to be ordinary
  /// rather than an error — [Image.network] gets an errorBuilder and the icon
  /// takes over silently.

  Widget _logo(ColorScheme cs) {
    final favicon = station.favicon;
    final fallback = Icon(Icons.radio, color: cs.primary);

    if (favicon == null || favicon.isEmpty) return fallback;

    return SizedBox(
      width: 40,
      height: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          favicon,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
