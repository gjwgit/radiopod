/// GeoBlockListener — explain a station that refuses our country.
///
// Time-stamp: <Wednesday 2026-10-14 09:00:00 +1100 Graham Williams>
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

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:radiopod/services/geo_block.dart';
import 'package:radiopod/widgets/error_dialog.dart';

/// Shows a dialog for each station in [blocks] that refused our country.
///
/// A dialog rather than a SnackBar: the listener would otherwise be left
/// thinking the app is at fault, and the remedy (a VPN, another station)
/// is theirs to choose.

class GeoBlockListener extends StatefulWidget {
  const GeoBlockListener({
    super.key,
    required this.blocks,
    required this.child,
  });

  final Stream<GeoBlock> blocks;

  final Widget child;

  @override
  State<GeoBlockListener> createState() => _GeoBlockListenerState();
}

class _GeoBlockListenerState extends State<GeoBlockListener> {
  late final StreamSubscription<GeoBlock> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.blocks.listen(_show);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  void _show(GeoBlock block) {
    if (!mounted) return;

    final where = block.country.isEmpty
        ? 'your country'
        : 'your country (${block.country})';

    unawaited(
      showErrorDialog(
        context,
        title: '${block.station} is not available here',
        message:
            'The broadcaster does not allow listening from $where. Its '
            'server sends a few seconds of audio and then stops, which is '
            'why the station kept dropping out and RadioPod moved on.\n\n'
            'A VPN connecting through the broadcaster\'s own country may let '
            'it play.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
