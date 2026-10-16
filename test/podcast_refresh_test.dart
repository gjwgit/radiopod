/// Refresh podcasts tests — what the toolbar button reports.
///
// Time-stamp: <Friday 2026-10-16 06:00:00 +1100 Graham Williams>
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

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';
import 'package:radiopod/widgets/podcast_refresh_action.dart';

void main() {
  group('podcastRefreshMessage', () {
    test('counts new episodes', () {
      expect(
        podcastRefreshMessage((podcasts: 3, newCasts: 2, failed: [])),
        'Checked 3 podcasts: 2 new episodes.',
      );
      expect(
        podcastRefreshMessage((podcasts: 1, newCasts: 1, failed: [])),
        'Checked 1 podcast: 1 new episode.',
      );
    });

    test('says so when nothing is new', () {
      expect(
        podcastRefreshMessage((podcasts: 2, newCasts: 0, failed: [])),
        'Checked 2 podcasts: no new episodes.',
      );
    });

    test('names the feeds that failed and counts only the rest', () {
      final m = podcastRefreshMessage((
        podcasts: 3,
        newCasts: 1,
        failed: ['The Daily', 'Up First'],
      ));

      expect(m, startsWith('Checked 1 podcast: 1 new episode.'));
      expect(m, contains('Could not fetch The Daily, Up First.'));
      expect(m, contains('their episodes are as they were'));
    });
  });

  group('refreshAllPodcasts', () {
    const pod = Station(
      id: 'p1',
      name: 'Future Tense',
      url: 'https://feeds.example/ft',
      isPodcast: true,
    );
    const radio = Station(id: 's1', name: 'Zulu FM', url: 'https://z.example');

    test('counts only podcasts', () async {
      final p = AppProvider()..loadForTest(const [pod, radio], const []);

      expect((await p.refreshAllPodcasts()).podcasts, 1);
    });

    test('a second tap during a run shares that run', () async {
      final p = AppProvider()..loadForTest(const [pod], const []);
      final first = p.refreshAllPodcasts();

      expect(identical(p.refreshAllPodcasts(), first), isTrue);
      await first;
      expect(identical(p.refreshAllPodcasts(), first), isFalse);
    });
  });
}
