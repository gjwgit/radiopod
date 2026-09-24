/// Add a station by hand, for one that Radio-Browser does not list.
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

import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/stations_widgets/station_icon_field.dart';
import 'package:radiopod/utils/station_icon.dart';

/// Whether [url] is something just_audio could be handed.
///
/// Deliberately permissive. Plain http is NOT rejected — a large share of
/// long-standing stations still stream over it, which is why the app ships
/// the cleartext exemptions — and no attempt is made to check the address
/// resolves or returns audio. That would mean a network round trip inside a
/// dialog, and the honest answer only arrives when the station is played.

bool isPlayableUrl(String url) {
  final uri = Uri.tryParse(url.trim());

  return uri != null &&
      (uri.isScheme('http') || uri.isScheme('https')) &&
      uri.host.isNotEmpty;
}

/// Ask for a name, a stream address and optionally a picture.
///
/// Returns the new station, or null if cancelled. The caller saves it, so
/// this dialog owns no provider and can be tested on its own.

Future<Station?> showNewStationDialog(
  BuildContext context, {
  required bool Function(String url) isDuplicate,
}) {
  return showDialog<Station>(
    context: context,
    builder: (context) => _NewStationDialog(isDuplicate: isDuplicate),
  );
}

class _NewStationDialog extends StatefulWidget {
  final bool Function(String url) isDuplicate;

  const _NewStationDialog({required this.isDuplicate});

  @override
  State<_NewStationDialog> createState() => _NewStationDialogState();
}

class _NewStationDialogState extends State<_NewStationDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();

  String? _icon;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _url.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  String get _trimmedName => _name.text.trim();
  String get _trimmedUrl => _url.text.trim();

  /// Why the address will not do, or null when it is fine.
  ///
  /// Nothing is said about an empty box: the user has not finished typing,
  /// and complaining before they have is just noise.

  String? get _urlError {
    if (_trimmedUrl.isEmpty) return null;
    if (!isPlayableUrl(_trimmedUrl)) {
      return 'Enter a full address, starting with http:// or https://';
    }
    if (widget.isDuplicate(_trimmedUrl)) {
      return 'A station with this stream address is already saved.';
    }

    return null;
  }

  bool get _canAdd =>
      _trimmedName.isNotEmpty && _trimmedUrl.isNotEmpty && _urlError == null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('New station'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a station RadioPod does not already know about. It is '
                'saved to your library only — nothing is submitted to the '
                'Radio-Browser database.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              const Gap(16),

              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const Gap(16),

              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Stream URL',
                  hintText: 'https://example.com/stream',
                  border: const OutlineInputBorder(),
                  errorText: _urlError,
                ),
              ),
              const Gap(20),

              // A new station advertises nothing, so there is never anything
              // to download and the field says so and offers Choose instead.
              StationIconField(
                icon: _icon,
                advertisedIcon: null,
                busy: _busy,
                message: _message,
                onDownload: () {},
                onChoose: _choose,
                onRemove: () => setState(() {
                  _icon = null;
                  _message = null;
                }),
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
          onPressed: _canAdd && !_busy ? _add : null,
          child: const Text('Add station'),
        ),
      ],
    );
  }

  void _add() => Navigator.of(context).pop(
    Station(
      id: const Uuid().v4(),
      name: _trimmedName,
      url: _trimmedUrl,
      icon: _icon,

      // Set from the address, the same test Search applies, so a hand-added
      // HLS stream is marked as one and its quirks are not a mystery later.
      isHls:
          Uri.tryParse(_trimmedUrl)?.path.toLowerCase().endsWith('.m3u8') ??
          false,
    ),
  );

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
