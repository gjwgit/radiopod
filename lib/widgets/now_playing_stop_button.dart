/// NowPlayingStopButton — a StopButton wired to the media session.
///
// Time-stamp: <Tuesday 2026-10-13 10:00:00 +1100 Graham Williams>
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

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/player.dart';
import 'package:radiopod/widgets/now_playing.dart';
import 'package:radiopod/widgets/stop_button.dart';

/// The Stop button shown beside the Stations filter and the Search box.
///
/// [stations] is where the name of the station on air is looked up: the
/// library on Stations, and the results as well on Search, where a station
/// can be previewed without being saved.

class NowPlayingStopButton extends StatelessWidget {
  const NowPlayingStopButton({super.key, required this.stations});

  final Iterable<Station> stations;

  @override
  Widget build(BuildContext context) => NowPlayingBuilder(
    builder: (context, now) => StopButton(
      active: now.playing || now.connecting || now.loading || now.paused,
      onStop: Player.handler.stop,

      // The media item outlives a Stop, so the station is still known and
      // play() re-opens it.
      onStart: now.stationId == null ? null : Player.handler.play,
      stationName: stations.where((s) => now.isCurrent(s.id)).firstOrNull?.name,
    ),
  );
}
