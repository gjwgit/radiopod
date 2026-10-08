/// Three stations to start an empty library with.
///
// Time-stamp: <Wednesday 2026-10-08 09:00:00 +1100 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0
//
/// Authors: Graham Williams

library;

import 'package:radiopod/models/station.dart';

/// Stations seeded into a library that has never had any.
///
/// 20261008 gjw HARDCODED, AND THAT IS THE POINT. RadioPod claims, in the
/// README and on the Settings screen, that it contacts exactly one third
/// party and only when you use Search. Fetching a popular-stations list at
/// start-up would make that claim false — it would tell Radio-Browser that
/// the app had been opened, before the user had asked for anything. So these
/// were looked up ONCE, by hand, and written down.
///
/// Chosen from Radio-Browser's own `topvote` ranking on 20261008, which is
/// the popularity measure the app's own search already draws on, filtered
/// down to stations that are:
///
///   - NOT HLS, which libmpv cannot hold open on the desktop (§7);
///   - reachable over https DIRECTLY, with no redirect. Dance Wave! and
///     REYFM both rank higher but bounce through a 302, the first to plain
///     http and the second to a URL carrying an expiry token — neither is
///     something to write into a constant;
///   - recognisable, since the whole job here is to show what the app does.
///
/// Each stream and each favicon was fetched and checked before being listed.
/// They will rot eventually, as station URLs do. That is survivable: these
/// are a starting point the user is free to delete, not a fixed library.
///
/// The ids are FIXED STRINGS rather than generated uuids, so that a station
/// seeded on the phone and one seeded on the desktop are the same station
/// should both ever reach the same Pod.

const demoStations = <Station>[
  Station(
    id: 'demo-bbc-world-service',
    name: 'BBC World Service',
    url: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service',
    homepage: 'https://www.bbc.co.uk/worldserviceradio',
    favicon: 'https://cdn-profiles.tunein.com/s24948/images/logoq.jpg',
    country: 'United Kingdom',
    language: 'english',
    codec: 'MP3',
    bitrate: 96,
    tags: ['news', 'talk', 'world'],
  ),
  Station(
    id: 'demo-radio-paradise',
    name: 'Radio Paradise',
    url: 'https://stream.radioparadise.com/aac-320',
    homepage: 'https://radioparadise.com/',
    favicon: 'https://radioparadise.com/apple-touch-icon.png',
    country: 'United States',
    language: 'english',
    codec: 'AAC',
    bitrate: 320,
    tags: ['eclectic', 'rock', 'listener supported'],
  ),
  Station(
    id: 'demo-mangoradio',
    name: 'MANGORADIO',
    url: 'https://mangoradio.stream.laut.fm/mangoradio',
    homepage: 'https://mangoradio.de/',
    favicon:
        'https://mangoradio.de/wp-content/uploads/cropped-Logo-192x192.webp',
    country: 'Germany',
    language: 'german',
    codec: 'MP3',
    bitrate: 128,
    tags: ['pop', 'charts'],
  ),
];
