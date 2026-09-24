/// StationDetails — the read-only facts about a station.
///
// Time-stamp: <Thursday 2026-09-25 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:radiopod/models/station.dart';

/// What is known about a station, below the parts of the properties dialog
/// that can be edited.
///
/// Grouped as Shortwave groups them — Information, Location, Audio — because
/// that ordering answers the questions in the order they are usually asked:
/// what is it, where is it from, and what will it sound like.
///
/// A ROW WITH NOTHING IN IT IS NOT SHOWN, and neither is a whole section
/// whose rows are all empty. Most of these fields come from Radio-Browser and
/// are filled in by whoever submitted the station, so they are patchy; a
/// station imported from a playlist file has none of them at all, carrying
/// only a name and a URL. A column of blank labels would suggest something
/// had failed rather than that nobody had ever typed it in.

class StationDetails extends StatelessWidget {
  final Station station;

  const StationDetails({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final s = station;

    final sections = <Widget?>[
      _section(context, 'Information', [
        _row('Language', s.language),
        _row('Genre', s.tags.isEmpty ? null : s.tags.join(', ')),
        _row('Homepage', s.homepage, copy: true, link: true),
      ]),
      _section(context, 'Location', [
        _row('Country', s.country),
        _row('State', s.state),
      ]),
      _section(context, 'Audio', [
        _row(
          'Bitrate',
          s.bitrate != null && s.bitrate! > 0 ? '${s.bitrate} kbit/s' : null,
        ),
        _row('Codec', s.codec),

        // Worth surfacing rather than hiding in a subtitle: an HLS stream is
        // the one that dies after a minute on the desktop, and knowing that
        // is what points the listener at the station's other entry.
        _row('Format', s.isHls ? 'HLS — a playlist of segments' : null),
        _row('Stream', s.url, copy: true, link: true),
      ]),
    ].whereType<Widget>().toList();

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  /// One section, or null when every row in it is empty.

  Widget? _section(BuildContext context, String title, List<_Row?> rows) {
    final present = rows.whereType<_Row>().toList();
    if (present.isEmpty) return null;

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const Gap(8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                for (var i = 0; i < present.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: cs.outlineVariant),
                  _tile(context, present[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, _Row row) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                ),
                const Gap(2),

                // Selectable so a value can be picked out by hand even where
                // the copy button is not what is wanted. An address is shown
                // as a link and opens on a tap; SelectableText is kept under
                // it so selecting still works either way.
                if (row.link)
                  InkWell(
                    onTap: () => openUrl(context, row.value),
                    child: Text(
                      row.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: cs.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  SelectableText(
                    row.value,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                  ),
              ],
            ),
          ),
          if (row.copy)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: 'Copy the ${row.label.toLowerCase()}',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: row.value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${row.label} copied.')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  /// A row, or null when there is nothing to put in it.

  _Row? _row(
    String label,
    String? value, {
    bool copy = false,
    bool link = false,
  }) {
    if (value == null || value.trim().isEmpty) return null;

    return _Row(label, value.trim(), copy, link);
  }
}

class _Row {
  final String label;
  final String value;
  final bool copy;

  /// Whether the value is an address to hand to the desktop.

  final bool link;

  const _Row(this.label, this.value, this.copy, this.link);
}

/// Open [url] with whatever the system uses for it.
///
/// Reports rather than throws. A homepage can be launched into a browser
/// almost anywhere, but a STREAM address depends on the desktop having
/// something registered for audio, and under strict snap confinement the
/// launch goes through a portal that may simply decline. Silence would leave
/// the user tapping a link that appears to do nothing.

Future<void> openUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(url);

  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[StationDetails] could not open $url: $e');
    }
  }

  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Nothing on this system would open that address.'),
      ),
    );
  }
}
