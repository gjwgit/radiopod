/// AfterCastSection — Settings: what plays when an episode finishes.
///
// Time-stamp: <Saturday 2026-10-24 10:00:00 +1100 Graham Williams>
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

import 'package:radiopod/services/after_cast_preference.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/utils/cast_merge.dart';

/// What plays when a podcast episode finishes.
///
/// 20261024 gjw Held by the audio handler, not this screen, because an
/// episode usually finishes with the phone in a pocket or the car driving:
/// the handler reads the choice when it needs it, and this writes both the
/// handler and storage, as the sleep timer's section does.

class AfterCastSection extends StatefulWidget {
  const AfterCastSection({super.key});

  @override
  State<AfterCastSection> createState() => _AfterCastSectionState();
}

class _AfterCastSectionState extends State<AfterCastSection> {
  AfterCast _choice = Player.handler.afterCast;

  Future<void> _choose(AfterCast? choice) async {
    if (choice == null) return;

    setState(() => _choice = choice);
    Player.handler.afterCast = choice;
    await AfterCastPreference.save(choice);
  }

  static const _choices = {
    AfterCast.newest: (
      'The newest episode still to hear',
      'Go back to the latest. Best for news, where the newest matters most.',
    ),
    AfterCast.older: (
      'The next older episode',
      'Carry on down the list, newest to oldest, to work through a podcast.',
    ),
    AfterCast.partHeard: (
      'An episode you started',
      'Carry on with the episode you were part-way through most recently, '
          'or else the newest still to hear, as tapping the podcast does.',
    ),
    AfterCast.nextStation: (
      'The next station',
      'Play one episode at a time, then move on through your list.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(32),
        Text(
          'When an episode finishes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Gap(8),
        Text(
          'What to play next, here, on the lock screen and in the car. Played '
          'and skipped episodes are never chosen, and when a podcast has '
          'nothing left, the next station in the list plays.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        RadioGroup<AfterCast>(
          groupValue: _choice,
          onChanged: _choose,
          child: Column(
            children: [
              for (final MapEntry(key: choice, value: (title, subtitle))
                  in _choices.entries)
                RadioListTile<AfterCast>(
                  contentPadding: EdgeInsets.zero,
                  value: choice,
                  title: Text(title),
                  subtitle: Text(subtitle),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
