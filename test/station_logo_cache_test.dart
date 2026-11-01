/// Tests for keeping station logos on the device.
///
// Time-stamp: <Sunday 2026-10-18 06:00:00 +1100 Graham Williams>
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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/station_logo_cache.dart';

const _a = 'https://logo.example/a.png';
const _b = 'https://logo.example/b.png';

Station _station(String id, String? favicon, {String? icon}) => Station(
  id: id,
  name: id,
  url: 'https://live.example/$id',
  favicon: favicon,
  icon: icon,
);

void main() {
  late Directory dir;

  setUp(() {
    StationLogoCache.resetForTest();
    dir = Directory.systemTemp.createTempSync('station_icons');
  });

  tearDown(() {
    StationLogoCache.resetForTest();
    dir.deleteSync(recursive: true);
  });

  /// Put a logo for [url] on disk and tell the cache it is kept.

  File keep(String url) {
    final file = File('${dir.path}/${StationLogoCache.fileName(url)}')
      ..writeAsBytesSync([1, 2, 3]);
    StationLogoCache.debugSetKept(url, dir.path);

    return file;
  }

  test('file names are per URL, so a moved logo is a new file', () {
    expect(StationLogoCache.fileName(_a), StationLogoCache.fileName(_a));
    expect(StationLogoCache.fileName(_a), isNot(StationLogoCache.fileName(_b)));
    expect(StationLogoCache.fileName(_a), matches(r'^logo_[0-9a-f]{40}\.png$'));
  });

  test('only a kept logo has a path; nothing is fetched to find out', () {
    keep(_a);

    expect(
      StationLogoCache.pathFor(_a),
      endsWith(StationLogoCache.fileName(_a)),
    );
    expect(StationLogoCache.pathFor(_b), isNull);
    expect(StationLogoCache.pathFor(null), isNull);
    expect(StationLogoCache.uriFor(_b), isNull);
  });

  test('iconFor reads the kept copy, for Properties → Download', () {
    keep(_a);

    expect(StationLogoCache.iconFor(_a), base64Encode([1, 2, 3]));
    expect(StationLogoCache.iconFor(_b), isNull);
  });

  test('sync drops logos no station uses any more', () async {
    final a = keep(_a);
    final b = keep(_b);

    await StationLogoCache.sync([_station('s1', _a)]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(a.existsSync(), isTrue);
    expect(b.existsSync(), isFalse);
    expect(StationLogoCache.pathFor(_b), isNull);
  });

  test('a chosen icon wins, so its station keeps no logo', () async {
    final a = keep(_a);

    await StationLogoCache.sync([_station('s1', _a, icon: 'abc')]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(a.existsSync(), isFalse);
  });

  test('an empty library deletes nothing', () async {
    final a = keep(_a);

    await StationLogoCache.sync(const []);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(a.existsSync(), isTrue);
  });
}
