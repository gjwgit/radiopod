/// StationIconField — the artwork row of the station properties dialog.
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

import 'package:gap/gap.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/utils/station_icon.dart';

/// A preview of the station's icon and the three things that can be done to
/// it: take the one the station advertises, choose a picture, or clear it.
///
/// Split out of the dialog because the dialog was over the 300 line limit
/// with it inline, and because the preview needs its own fallback logic.

class StationIconField extends StatelessWidget {
  final String? icon;
  final Station station;
  final bool busy;
  final String? message;
  final VoidCallback onDownload;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  const StationIconField({
    super.key,
    required this.icon,
    required this.station,
    required this.busy,
    required this.message,
    required this.onDownload,
    required this.onChoose,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Only offer the download when the station actually advertises an
    // address. Most imported stations do not, and a button that can only
    // fail is worse than no button.

    final advertises = station.favicon != null && station.favicon!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Icon', style: Theme.of(context).textTheme.labelLarge),
        const Gap(8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _preview(cs),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.cloud_download_outlined,
                          size: 18,
                        ),
                        label: const Text('Download'),
                        onPressed: busy || !advertises ? null : onDownload,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Choose…'),
                        onPressed: busy ? null : onChoose,
                      ),
                      if (icon != null)
                        TextButton(
                          onPressed: busy ? null : onRemove,
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                  if (!advertises && icon == null) ...[
                    const Gap(6),
                    Text(
                      'This station advertises no icon, so there is nothing '
                      'to download. Choose a picture instead.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (message != null) ...[
                    const Gap(6),
                    Text(
                      message!,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The icon as it will appear in the list: the stored bytes if there are
  /// any, otherwise whatever the advertised address yields, otherwise the
  /// same radio glyph the rows fall back to.

  Widget _preview(ColorScheme cs) {
    final stored = decodeStationIcon(icon);
    final fallback = Icon(Icons.radio, size: 30, color: cs.primary);

    Widget inner;
    if (busy) {
      inner = const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (stored != null) {
      inner = Image.memory(stored, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (station.favicon != null && station.favicon!.isNotEmpty) {
      inner = Image.network(
        station.favicon!,
        fit: BoxFit.cover,
        // See station_tile.dart for why the web needs this.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      inner = fallback;
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: inner),
    );
  }
}
