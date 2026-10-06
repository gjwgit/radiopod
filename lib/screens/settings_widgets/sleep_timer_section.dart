/// The Settings section choosing how long the sleep timer runs.
///
// Time-stamp: <Tuesday 2026-10-06 20:00:00 +1100 Graham Williams>
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

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/services/sleep_preference.dart';
import 'package:radiopod/utils/sleep_timer_text.dart';

/// How long the sleep timer runs when it is switched on.
///
/// 20261006 gjw The LENGTH is set here and the SWITCH is in the app bar,
/// deliberately apart. Choosing half an hour against an hour is a decision
/// made once; turning the timer on is done nightly, and having to pick a
/// duration every time would be the sort of friction that stops it being
/// used at all.

class SleepTimerSection extends StatefulWidget {
  const SleepTimerSection({super.key});

  @override
  State<SleepTimerSection> createState() => _SleepTimerSectionState();
}

class _SleepTimerSectionState extends State<SleepTimerSection> {
  /// Read from the timer rather than from storage: Player.init has already
  /// loaded the stored value into it, and the two must not drift apart.

  Duration _duration = Player.sleepTimer.defaultDuration;

  Future<void> _choose(Duration? duration) async {
    if (duration == null) return;

    setState(() => _duration = duration);

    // Both, always. The timer is what the app bar acts on, storage is what
    // the next launch reads, and leaving either behind would make the
    // setting look like it had not taken.

    Player.sleepTimer.defaultDuration = duration;
    await SleepPreference.save(duration);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(32),
        Text('Sleep timer', style: Theme.of(context).textTheme.titleLarge),
        const Gap(8),
        Text(
          'Tap the timer in the toolbar to keep playing for a while and then '
          'stop. Only playback stops: the app stays open and your library is '
          'untouched, so a station is one tap away again.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const Gap(12),
        Row(
          children: [
            const Icon(Icons.timer_outlined),
            const Gap(12),
            const Text('Keep playing for'),
            const Gap(12),
            DropdownButton<Duration>(
              value: _duration,
              onChanged: _choose,
              items: [
                for (final choice in sleepTimerChoices)
                  DropdownMenuItem<Duration>(
                    value: choice,
                    child: Text(sleepTimerLabel(choice)),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
