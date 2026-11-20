/// Station properties — rename, reconnect behaviour and artwork.
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

import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/stations_widgets/on_air_track.dart';
import 'package:radiopod/screens/stations_widgets/station_details.dart';
import 'package:radiopod/screens/stations_widgets/station_icon_field.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/services/station_logo_cache.dart';
import 'package:radiopod/services/station_update.dart';
import 'package:radiopod/utils/station_icon.dart';
import 'package:radiopod/widgets/app_snack_bar.dart';

/// Show and edit [station], saving any change to the library.
///
/// The one way in, from a station's Information on Stations and Playlists
/// and a podcast's Episodes page alike, so both save and report a change the same way.

Future<void> editStationProperties(
  BuildContext context,
  Station station,
) async {
  final provider = context.read<AppProvider>();
  final updated = await showStationPropertiesDialog(context, station);
  if (updated == null || !context.mounted) return;

  await provider.updateStation(updated);
  if (!context.mounted) return;
  showPositiveSnackBar(context, 'Updated ${updated.name}.');
}

/// Show everything about [station] and edit it, returning the changed copy,
/// or null if cancelled or left unchanged.
///
/// 20261028 gjw Also the station's information, which had a dialog of its
/// own for a day: one button, one place. While the station is on air it
/// opens with the whole title of what is playing.

Future<Station?> showStationPropertiesDialog(
  BuildContext context,
  Station station,
) {
  return showDialog<Station>(
    context: context,
    builder: (context) => _StationPropertiesDialog(station: station),
  );
}

class _StationPropertiesDialog extends StatefulWidget {
  final Station station;

  const _StationPropertiesDialog({required this.station});

  @override
  State<_StationPropertiesDialog> createState() => _DialogState();
}

class _DialogState extends State<_StationPropertiesDialog> {
  late final _name = TextEditingController(text: widget.station.name);

  late bool _reconnect = widget.station.reconnectOnEnd;
  late String? _icon = widget.station.icon;

  /// The station as it stands, including anything a refresh has brought
  /// down. Held here rather than written straight through, so a refresh is
  /// reviewed and then Saved like any other edit — and can be abandoned with
  /// Cancel if what came back is worse than what was there.

  late Station _station = widget.station;

  /// What the refresh reported, shown under the button.

  String? _refreshMessage;
  bool _refreshing = false;

  /// What the icon controls are doing, so the buttons can be disabled and
  /// the outcome reported inline rather than in a SnackBar behind a dialog.

  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();

  /// Save stays disabled until something actually differs, so an accidental
  /// OK cannot rewrite the station list on the Pod for nothing.

  bool get _changed =>
      !identical(_station, widget.station) ||
      (_trimmed.isNotEmpty && _trimmed != widget.station.name) ||
      _reconnect != widget.station.reconnectOnEnd ||
      _icon != widget.station.icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final podcast = widget.station.isPodcast;

    return AlertDialog(
      title: Text(podcast ? 'Podcast properties' : 'Station information'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A podcast's episode on air is on the Episodes page.
              if (!podcast) OnAirTrackFollower(stationId: widget.station.id),

              // 20261028 gjw No autofocus. The dialog is opened as often to
              // read as to edit, and on a phone a focused field brings up
              // the keyboard over what there is to read.
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(),
                  errorText: _trimmed.isEmpty ? 'A name is required.' : null,
                ),
              ),
              const Gap(20),

              StationIconField(
                icon: _icon,
                advertisedIcon: widget.station.favicon,
                busy: _busy,
                message: _message,
                onDownload: _download,
                onChoose: _choose,
                onRemove: () => setState(() {
                  _icon = null;
                  _message = null;
                }),
              ),

              // 20261017 gjw No reconnect switch for a podcast. An episode
              // that ends has finished, and the next older one plays; there
              // is no connection to pick back up.
              if (!podcast) ...[
                const Gap(12),
                MarkdownTooltip(
                  message: '''

                **Reconnect when the stream ends**

                Turn this ON for a continuous station whose connection drops
                between programmes — ABC News Radio does this — so RadioPod
                opens it again and the broadcast carries on.

                Leave it OFF for a bulletin that genuinely finishes, like NPR
                Newscast. Reconnecting there would replay the same news, so
                RadioPod moves to the next station instead.

                ''',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reconnect when the stream ends'),
                    subtitle: Text(
                      _reconnect
                          ? 'A continuous station: open it again.'
                          : 'A programme that finishes: move to the next '
                                'station.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    value: _reconnect,
                    onChanged: (v) => setState(() => _reconnect = v),
                  ),
                ),
              ],

              // What is known about the station, below what can be changed
              // about it. Read-only, and quiet about anything unknown.
              StationDetails(station: _station, full: true),

              const Gap(16),
              _refreshControl(cs),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          // Close while there is nothing to lose, as when only reading.
          child: Text(_changed ? 'Cancel' : 'Close'),
        ),
        FilledButton(
          onPressed: _changed && !_busy ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  /// The control for bringing the details up to date.
  ///
  /// 20261014 gjw Offered for EVERY station. One from Search is looked up by
  /// its Radio-Browser id; one added by hand or imported from a playlist file
  /// has none, so it is looked up by its address instead, which often finds
  /// it. It used to be disabled for those, which left a hand-added station
  /// with a bare subtitle for good. 20261017 gjw Labelled Update details,
  /// not Update from Radio-Browser: a podcast updates from its own feed.

  Widget _refreshControl(ColorScheme cs) {
    final note = _refreshMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          icon: _refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync, size: 18),
          label: const Text('Update details'),
          onPressed: _refreshing ? null : _refresh,
        ),
        if (note != null) ...[
          const Gap(6),
          Text(
            note,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ],
    );
  }

  /// Everything the refresh brought down, with the three things this dialog
  /// owns laid over the top. The user's own icon in particular is never
  /// replaced by a refresh: they chose it deliberately.

  void _save() => Navigator.of(context).pop(
    _station.copyWith(name: _trimmed, reconnectOnEnd: _reconnect, icon: _icon),
  );

  /// Fetch the details again, from Radio-Browser or the podcast's feed.
  ///
  /// Updates the ADDRESS as well as the details. That is the point of the
  /// exercise: a station that has stopped playing has often simply moved,
  /// and the saved uuid is what finds where it moved to.
  ///
  /// The name goes into the text field rather than being applied silently,
  /// so a station renamed to something personal is not quietly reverted
  /// without the user seeing it happen.

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _refreshMessage = null;
    });
    try {
      final update = await updateStationDetails(
        _station,
        reconnectOnEnd: _reconnect,
        icon: _icon,
      );
      if (!mounted) return;

      setState(() {
        _refreshMessage = update.message;
        if (update.station != null) _station = update.station!;
        if (update.name != null) _name.text = update.name!;
      });
    } catch (e) {
      if (!mounted) return;
      final source = widget.station.isPodcast
          ? 'the podcast\'s feed'
          : 'Radio-Browser';
      setState(() => _refreshMessage = 'Could not reach $source. $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Fetch the artwork the station advertises, if it still has any.

  Future<void> _download() async {
    final url = widget.station.favicon;
    if (url == null || url.isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    final fetched =
        StationLogoCache.iconFor(url) ?? await fetchStationIcon(url);
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (fetched == null) {
        // Not an error worth a dialog: Radio-Browser's favicon links rot,
        // and plenty were never images in the first place.

        _message = 'No usable icon at the address advertised.';
      } else {
        _icon = fetched;
        _message = 'Downloaded.';
      }
    });
  }

  /// Use a picture of the user's own instead.

  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose a station icon',
        type: FileType.image,
      );
      if (file == null) return;

      final encoded = await encodeStationIcon(await file.readAsBytes());
      if (!mounted) return;

      setState(() {
        if (encoded == null) {
          _message = 'That file could not be read as an image.';
        } else {
          _icon = encoded;
          _message = null;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
