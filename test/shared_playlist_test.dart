/// Tests for taking in playlists that other Solid users have shared.
///
// Time-stamp: <Monday 2026-11-02 12:00:00 +1100 Tony Chen>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3
//
/// Authors: Tony Chen

library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/app_provider.dart';

const _url = 'https://owner.example/radiopod/data/playlist_abc.ttl';
const _owner = 'https://owner.example/profile/card#me';

const _mine = Station(id: 'm1', name: 'Mine', url: 'https://live.example/a');
const _same = Station(
  id: 'o1',
  name: 'Theirs A',
  url: 'https://live.example/a',
);
const _new = Station(id: 'o2', name: 'Custom', url: 'https://live.example/z');

AppProvider _provider() => AppProvider()
  ..loadForTest(
    const [_mine],
    const [
      Playlist(id: 'p1', name: 'Drive', stationIds: ['m1']),
    ],
  );

Playlist _shared(AppProvider p) =>
    p.playlists.firstWhere((x) => x.sharedFrom == _url);

void main() {
  group('taking in a share', () {
    test('adds the playlist, linked to the owner', () {
      final p = _provider();

      expect(
        p.takeInShared(_url, _owner, '20261102T100000', (
          name: 'Road trip',
          stations: [_same, _new],
        )),
        isTrue,
      );

      final s = _shared(p);
      expect(s.name, 'Road trip');
      expect(s.isShared, isTrue);
      expect(s.sharedBy, _owner);
      expect(s.sharedAt, '20261102T100000');
      expect(p.playlists, hasLength(2));
    });

    test('reuses a station the library has and adds the rest', () {
      final p = _provider()
        ..takeInShared(_url, _owner, 't1', (
          name: 'Road trip',
          stations: [_same, _new],
        ));

      // Matched by stream address, not by the owner's id.

      expect(p.stations, hasLength(2));
      final ids = _shared(p).stationIds;
      expect(ids.first, 'm1');

      // The owner's custom station is now in the library, under a new id.

      final custom = p.stations.firstWhere((s) => s.url == _new.url);
      expect(custom.name, 'Custom');
      expect(custom.id, isNot('o2'));
      expect(ids.last, custom.id);
      expect(p.stationsOf(_shared(p)).map((s) => s.url), [_same.url, _new.url]);
    });

    test('a second take-in refreshes rather than duplicates', () {
      final p = _provider()
        ..takeInShared(_url, _owner, 't1', (
          name: 'Road trip',
          stations: [_same],
        ));

      p.renamePlaylist(_shared(p).id, 'My name for it');

      expect(
        p.takeInShared(_url, _owner, 't2', (
          name: 'Road trip',
          stations: [_new, _same],
        )),
        isTrue,
      );

      expect(p.playlists.where((x) => x.isShared), hasLength(1));
      expect(_shared(p).name, 'My name for it', reason: 'rename is kept');
      expect(p.stationsOf(_shared(p)).map((s) => s.url), [_new.url, _same.url]);
      expect(p.stations, hasLength(2));
    });

    test('nothing changed reports no change', () {
      final p = _provider()
        ..takeInShared(_url, _owner, 't1', (
          name: 'Road trip',
          stations: [_same],
        ));

      expect(
        p.takeInShared(_url, _owner, 't1', (
          name: 'Road trip',
          stations: [_same],
        )),
        isFalse,
      );
    });
  });

  group('reading what was shared', () {
    test('only shared playlist files are picked out of the log', () {
      expect(isSharedPlaylistUrl(_url), isTrue);
      expect(
        isSharedPlaylistUrl('https://o.example/notepod/data/note-1.ttl'),
        isFalse,
      );
      expect(
        isSharedPlaylistUrl('https://o.example/radiopod/data/playlists.ttl'),
        isFalse,
      );
    });

    test('decodes the file the owner wrote', () {
      final json = jsonEncode({
        'name': 'Road trip',
        'stations': [_same.toJson(), _new.toJson()],
      });
      final shared = decodeSharedPlaylist(json)!;

      expect(shared.name, 'Road trip');
      expect(shared.stations.map((s) => s.url), [_same.url, _new.url]);
    });

    test('an unreadable file is skipped, not thrown', () {
      expect(decodeSharedPlaylist('[1, 2]'), isNull);
      expect(decodeSharedPlaylist('not json'), isNull);
    });

    test('the record of grants taken in survives a round trip', () {
      expect(decodeSeenShares(null), isEmpty);
      expect(decodeSeenShares('garbage'), isEmpty);
      expect(decodeSeenShares(jsonEncode({_url: 't1'})), {_url: 't1'});
    });
  });

  test('a shared playlist keeps its link through JSON', () {
    const p = Playlist(
      id: 'p9',
      name: 'Road trip',
      stationIds: ['a'],
      sharedFrom: _url,
      sharedBy: _owner,
      sharedAt: 't1',
    );
    final back = Playlist.fromJson(p.toJson());

    expect(back.sharedFrom, _url);
    expect(back.sharedBy, _owner);
    expect(back.sharedAt, 't1');

    // An own playlist writes no share fields at all.

    expect(const Playlist(id: 'x', name: 'y').toJson().keys, [
      'id',
      'name',
      'stationIds',
    ]);
  });
}
