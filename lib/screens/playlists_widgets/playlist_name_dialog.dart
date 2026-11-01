/// Playlist name dialog — create or rename a playlist.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
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

/// Ask for a playlist name, returning it trimmed, or null if cancelled.
///
/// Pass [initial] to rename rather than create. Save stays disabled until
/// there is a name AND it differs from [initial], so an accidental OK on an
/// unchanged rename writes nothing to the Pod.

Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PlaylistNameDialog(title: title, initial: initial),
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  final String title;
  final String initial;

  const _PlaylistNameDialog({required this.title, required this.initial});

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  bool get _canSave => _name.isNotEmpty && _name != widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) {
          if (_canSave) Navigator.of(context).pop(_name);
        },
        decoration: const InputDecoration(
          labelText: 'Playlist name',
          hintText: 'e.g. Morning drive',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave ? () => Navigator.of(context).pop(_name) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
