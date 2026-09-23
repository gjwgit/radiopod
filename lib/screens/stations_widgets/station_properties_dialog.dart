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
import 'package:radiopod/screens/stations_widgets/station_icon_field.dart';
import 'package:radiopod/utils/station_icon.dart';

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
                station: widget.station,
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

  void _save() => Navigator.of(context).pop(
    widget.station.copyWith(
      name: _trimmed,
      reconnectOnEnd: _reconnect,
      icon: _icon,
    ),
  );

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
