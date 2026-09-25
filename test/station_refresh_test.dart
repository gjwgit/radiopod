/// Tests for updating a saved station from Radio-Browser.
///
// Time-stamp: <Thursday 2026-09-25 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/screens/stations_widgets/station_properties_dialog.dart';

/// The station as saved: renamed by the listener, given their own picture,
/// set to reconnect, and pointing at an address that has since moved.

const _current = Station(
  id: 'local-id-1',
  name: 'Auntie news',
  url: 'http://old.example/stream',
  country: 'Australia',
  codec: 'MP3',
  bitrate: 64,
  stationUuid: '89dda6cb-e1f1-4498-9b6f-ce0054707c01',
  reconnectOnEnd: true,
  icon: 'CHOSEN-BY-HAND',
);

/// The same station as Radio-Browser now has it.

const _fresh = Station(
  id: 'whatever-uuid-the-parser-made',
  name: 'ABC News Radio',
  url: 'https://new.example/live/newsradio',
  country: 'Australia',
  state: 'NSW',
  language: 'english',
  codec: 'AAC+',
  bitrate: 56,
  homepage: 'https://www.abc.net.au/listen/news',
  favicon: 'https://example.com/logo.png',
  stationUuid: '89dda6cb-e1f1-4498-9b6f-ce0054707c01',
  isHls: true,
);

Station _merged() => applyRefresh(
  _fresh,
  _current,
  reconnectOnEnd: _current.reconnectOnEnd,
  icon: _current.icon,
);

void main() {
  group('applyRefresh keeps what belongs to the listener', () {
    test('the local id, which playlists reference', () {
      // Taking the fetched id would drop the station out of every playlist
      // holding it, silently and with no way back.

      expect(_merged().id, 'local-id-1');
    });

    test('the reconnect choice, which the database has no opinion on', () {
      expect(_merged().reconnectOnEnd, isTrue);
    });

    test('a picture they chose by hand', () {
      expect(_merged().icon, 'CHOSEN-BY-HAND');
    });

    test('and does not put the choice back when there was none', () {
      final m = applyRefresh(
        _fresh,
        _current,
        reconnectOnEnd: false,
        icon: null,
      );

      expect(m.reconnectOnEnd, isFalse);
      expect(m.icon, isNull);
    });
  });

  group('applyRefresh takes what belongs to Radio-Browser', () {
    test('the stream address, which is the point of the exercise', () {
      // Station.stationUuid is kept precisely so a moved station can be
      // found again.

      expect(_merged().url, 'https://new.example/live/newsradio');
    });

    test('the details', () {
      final m = _merged();

      expect(m.codec, 'AAC+');
      expect(m.bitrate, 56);
      expect(m.state, 'NSW');
      expect(m.language, 'english');
      expect(m.homepage, 'https://www.abc.net.au/listen/news');
      expect(m.favicon, 'https://example.com/logo.png');
    });

    test('and whether it is now an HLS stream', () {
      // A station that has moved to segments is one that will start dying
      // after a minute on the desktop, so this must not go stale.

      expect(_current.isHls, isFalse);
      expect(_merged().isHls, isTrue);
    });

    test('the name, which the dialog then shows for review', () {
      // Returned here rather than discarded; the dialog puts it in the text
      // field so a personal rename is not reverted without being seen.

      expect(_merged().name, 'ABC News Radio');
    });
  });
}
