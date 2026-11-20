/// TransferSection — one direction of the Transfer screen.
///
// Time-stamp: <Wednesday 2026-10-21 06:00:00 +1100 Graham Williams>
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

import 'package:gap/gap.dart';

import 'package:radiopod/screens/transfer_widgets/import_message_banner.dart';

/// A heading, what it does, the outcome of the last attempt if any, and the
/// actions: Import and Export are each one of these.

class TransferSection extends StatelessWidget {
  const TransferSection({
    super.key,
    required this.title,
    required this.explanation,
    required this.actions,
    this.message,
    this.isError = false,
  });

  final String title;
  final String explanation;
  final List<Widget> actions;
  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Gap(8),
        Text(explanation, style: TextStyle(color: cs.onSurfaceVariant)),
        if (message != null) ...[
          const Gap(12),
          ImportMessageBanner(message: message!, isError: isError, cs: cs),
        ],
        for (final (i, action) in actions.indexed) ...[
          Gap(i == 0 ? 16 : 12),
          action,
        ],
      ],
    );
  }
}
