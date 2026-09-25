/// Station properties — rename, reconnect behaviour and artwork.
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

import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/stations_widgets/station_details.dart';
import 'package:radiopod/screens/stations_widgets/station_icon_field.dart';
import 'package:radiopod/services/radio_browser.dart';
import 'package:radiopod/utils/station_icon.dart';

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

/// Edit [station], returning the changed copy, or null if cancelled.

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

    return AlertDialog(
      title: const Text('Station properties'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
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
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                  value: _reconnect,
                  onChanged: (v) => setState(() => _reconnect = v),
                ),
              ),

              // What is known about the station, below what can be changed
              // about it. Read-only, and quiet about anything unknown.
              StationDetails(station: _station),

              const Gap(16),
              _refreshControl(cs),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
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
  /// Offered only for a station that came from Search, since the lookup is by
  /// the Radio-Browser id and one imported from a playlist file has none. A
  /// button that could only ever fail is worse than no button, so it is
  /// disabled and the reason given.

  Widget _refreshControl(ColorScheme cs) {
    final known = widget.station.stationUuid != null;
    final note =
        _refreshMessage ??
        (known
            ? null
            : 'This station was not found through Search, so Radio-Browser '
                  'has no record to update it from.');

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
          label: const Text('Update from Radio-Browser'),
          onPressed: known && !_refreshing ? _refresh : null,
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

  /// Fetch this station's current record from Radio-Browser.
  ///
  /// Updates the ADDRESS as well as the details. That is the point of the
  /// exercise: a station that has stopped playing has often simply moved,
  /// and the saved uuid is what finds where it moved to.
  ///
  /// The name goes into the text field rather than being applied silently,
  /// so a station renamed to something personal is not quietly reverted
  /// without the user seeing it happen.

  Future<void> _refresh() async {
    final uuid = widget.station.stationUuid;
    if (uuid == null) return;

    setState(() {
      _refreshing = true;
      _refreshMessage = null;
    });
    try {
      final fresh = await RadioBrowser.lookup(uuid);
      if (!mounted) return;

      setState(() {
        if (fresh == null) {
          _refreshMessage =
              'Radio-Browser no longer lists this station. Entries are '
              'removed when they stop working.';

          return;
        }

        // Keep this station's own identity and the choices that belong to
        // the listener rather than to the database.

        _station = applyRefresh(
          fresh,
          widget.station,
          reconnectOnEnd: _reconnect,
          icon: _icon,
        );
        _name.text = fresh.name;
        _refreshMessage = 'Updated from Radio-Browser. Save to keep it.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshMessage = 'Could not reach Radio-Browser. $e';
      });
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
    final fetched = await fetchStationIcon(url);
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (fetched == null) {
        // Not an error worth a dialog: Radio-Browser's favicon links rot,
        // and plenty were never images in the first place.

        _message = 'No usable icon at the address this station advertises.';
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
