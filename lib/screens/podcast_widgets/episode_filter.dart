/// EpisodeFilter — the filter box atop a podcast's Episodes page.
///
// Time-stamp: <Sunday 2026-10-25 12:00:00 +1100 Graham Williams>
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

import 'package:markdown_tooltip/markdown_tooltip.dart';

/// A filter over the episodes' titles and show notes, drawn like the
/// Stations filter. [onChanged] is called on every edit, and on Clear.

class EpisodeFilter extends StatelessWidget {
  const EpisodeFilter({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.filter_list),
        hintText: 'Filter the episodes by title and show notes.',
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: controller.text.isEmpty
            ? null
            : MarkdownTooltip(
                message: '''

                **Clear**

                Clear the filter and list every episode.

                ''',
                child: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged();
                  },
                ),
              ),
      ),
    ),
  );
}
