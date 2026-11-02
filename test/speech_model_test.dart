/// Tests for choosing the captions model from a station's language.
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
/// Authors: Tony Chen

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/captions/speech_model.dart';

void main() {
  group('speechModelForLanguage', () {
    test(
      'English, however Radio-Browser spells it, gets the English model',
      () {
        for (final l in [
          'english',
          'English',
          'american english',
          'english uk',
        ]) {
          expect(speechModelForLanguage(l), englishSpeechModel, reason: l);
        }
      },
    );

    test('Chinese or Mandarin gets the bilingual model', () {
      for (final l in ['chinese', 'Mandarin', 'mandarin chinese', 'chinese,']) {
        expect(speechModelForLanguage(l), bilingualSpeechModel, reason: l);
      }
    });

    test(
      'a station listing both gets the bilingual model, which does both',
      () {
        expect(speechModelForLanguage('english,chinese'), bilingualSpeechModel);
        expect(
          speechModelForLanguage('mandarin,english'),
          bilingualSpeechModel,
        );
      },
    );

    test('any other language, or none, gets no model', () {
      for (final l in ['spanish', 'cantonese', 'japanese', '', null]) {
        expect(speechModelForLanguage(l), isNull, reason: '$l');
      }
    });

    test('is read from the station', () {
      const station = Station(
        id: 's',
        name: 'CNR-1',
        url: 'https://example/cnr1.mp3',
        language: 'chinese',
      );

      expect(speechModelFor(station), bilingualSpeechModel);
      expect(speechModelFor(null), isNull);
    });
  });

  test('every model fetches four files from its own folder', () {
    for (final m in speechModels) {
      expect(m.files, hasLength(4));
      expect(m.baseUrl, endsWith('/'));
      expect(m.uriOf(m.encoder).toString(), '${m.baseUrl}${m.encoder}');
    }
    expect(bilingualSpeechModel.sizeLabel, '60 MB');
  });
}
