/// Station filter — what the Stations filter box matches.
///
// Time-stamp: <Sunday 2026-10-25 10:00:00 +1100 Graham Williams>
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

import 'package:radiopod/models/cast.dart';
import 'package:radiopod/models/station.dart';

/// Whether [station] answers the Stations filter [query], already trimmed
/// and lower-cased. An empty query matches everything.
///
/// 20261025 gjw A podcast matches on more than its name: its description,
/// and the title and show notes of each of its [casts], so a topic finds
/// the podcast that covered it. The notes are the stored summary, the first
/// 400 characters; the full text is fetched only for an episode's Info. A
/// radio station has nothing more to search than its name.

bool stationMatches(Station station, List<Cast> casts, String query) {
  if (query.isEmpty) return true;

  if (_has(station.name, query)) return true;
  if (!station.isPodcast) return false;

  return _has(station.description, query) ||
      casts.any((c) => castMatches(c, query));
}

/// Whether [cast] answers the Episodes filter [query], already trimmed and
/// lower-cased: its title or its stored show notes. An empty query matches
/// everything.

bool castMatches(Cast cast, String query) =>
    query.isEmpty || _has(cast.title, query) || _has(cast.description, query);

bool _has(String? text, String query) =>
    text != null && text.toLowerCase().contains(query);
