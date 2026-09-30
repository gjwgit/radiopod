/// Caption engine stub, for WEB builds.
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

import 'dart:typed_data';

import 'package:radiopod/services/captions/speech_model.dart';

class SpeechModelStore {
  SpeechModelStore._();

  static Future<bool> isInstalled(SpeechModel model) async => false;

  static Future<void> download(
    SpeechModel model, {
    required void Function(double progress) onProgress,
    required bool Function() cancelled,
  }) => throw UnsupportedError('Captions are not available on the web.');

  static Future<void> delete(SpeechModel model) async {}
}

class RecognisedText {
  final String text;
  final bool isFinal;

  const RecognisedText(this.text, {required this.isFinal});
}

class Recogniser {
  Recogniser._();

  Stream<RecognisedText> get results => const Stream.empty();

  static Future<Recogniser> start(SpeechModel model) =>
      throw UnsupportedError('Captions are not available on the web.');

  void accept(Float32List samples) {}

  void reset() {}

  void close() {}
}
