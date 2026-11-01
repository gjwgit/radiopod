/// Tests for the line saying what is on, shown in the empty filter box.
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
import 'package:radiopod/widgets/now_playing.dart';

const _jazz = Station(id: 's1', name: 'ABC Jazz', url: 'https://x.example/j');
const _pod = Station(
  id: 'p1',
  name: 'Future Tense',
  url: 'https://x.example/f.xml',
  isPodcast: true,
);
const _library = [_jazz, _pod];

void main() {
  test('a station with its song', () {
    expect(
      nowPlayingLine(
        const NowPlaying(
          stationId: 's1',
          track: 'Miles Davis - So What',
          playing: true,
        ),
        _library,
      ),
      'ABC Jazz — Miles Davis - So What',
    );
  });

  test('a station that announces nothing', () {
    expect(
      nowPlayingLine(
        const NowPlaying(stationId: 's1', playing: true),
        _library,
      ),
      'ABC Jazz',
    );
  });

  test('a podcast with its cast, and paused says so', () {
    const cast = 'The danger of generational labelling';

    expect(
      nowPlayingLine(
        const NowPlaying(stationId: 'p1', track: cast, playing: true),
        _library,
      ),
      'Future Tense — $cast',
    );
    expect(
      nowPlayingLine(
        const NowPlaying(stationId: 'p1', track: cast, paused: true),
        _library,
      ),
      'Paused: Future Tense — $cast',
    );
  });

  test('nothing playing, or not in the library, is the usual prompt', () {
    expect(nowPlayingLine(const NowPlaying(), _library), isNull);
    expect(nowPlayingLine(const NowPlaying(stationId: 's1'), _library), isNull);
    expect(
      nowPlayingLine(
        const NowPlaying(stationId: 'search-preview', playing: true),
        _library,
      ),
      isNull,
    );
  });
}
