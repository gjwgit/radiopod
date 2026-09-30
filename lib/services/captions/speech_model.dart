/// SpeechModel — the recognition models captions are made with.
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

import 'package:radiopod/models/station.dart';

/// A streaming sherpa-onnx transducer, and where to fetch its files.
///
/// Kept free of `dart:io` so the settings screen can describe the models on
/// every platform; downloading and loading them live in the caption engine.

class SpeechModel {
  final String id;

  /// What the listener is told the model understands.

  final String language;

  /// The folder the files are fetched from, ending in a slash. Each file
  /// name is appended to it as it stands.

  final String baseUrl;

  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;

  /// Total download size, for the confirmation and the progress bar.

  final int bytes;

  const SpeechModel({
    required this.id,
    required this.language,
    required this.baseUrl,
    required this.encoder,
    required this.decoder,
    required this.joiner,
    this.tokens = 'tokens.txt',
    required this.bytes,
  });

  List<String> get files => [encoder, decoder, joiner, tokens];

  Uri uriOf(String file) => Uri.parse('$baseUrl$file');

  /// The server the files come from, for the privacy statement.

  String get host => Uri.parse(baseUrl).host;

  /// The size in megabytes, as a listener would say it.

  String get sizeLabel => '${(bytes / 1000000).round()} MB';
}

/// For English stations: a 20-million-parameter English zipformer.
///
/// SMALL ON PURPOSE. It runs comfortably on a phone alongside playback and
/// downloads in under a minute on a reasonable connection. The encoder and
/// joiner are the int8 builds; the decoder is left at full precision, as the
/// sherpa-onnx examples for this model do, since it is only 2 MB anyway.

const englishSpeechModel = SpeechModel(
  id: 'zipformer-en-20m-2023-02-17',
  language: 'English',
  baseUrl:
      'https://huggingface.co/csukuangfj/'
      'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17/resolve/main/',
  encoder: 'encoder-epoch-99-avg-1.int8.onnx',
  decoder: 'decoder-epoch-99-avg-1.onnx',
  joiner: 'joiner-epoch-99-avg-1.int8.onnx',
  bytes: 42845182 + 2092272 + 259572 + 5048,
);

/// For Chinese stations: the small bilingual Mandarin and English zipformer.
///
/// SELF-HOSTED. The only official copy is a 458 MB archive that also holds
/// full-precision duplicates, two alternative builds and test recordings;
/// the four files below are 60 MB of it, and asking every listener to fetch
/// the rest to get them would be absurd. They are served from
/// dev.empwr.au exactly as they came out of the archive, unmodified.
///
/// The folder holds this model's files alone. The English model's files have
/// the same names, so a second model hosted there would need a folder of its
/// own.
///
/// THE DECODER MUST BE FULL PRECISION. With the int8 decoder this model
/// produces fragments of nonsense on Mandarin broadcasts; with the full one,
/// on the same audio, it transcribes whole sentences correctly. Speed is the
/// same either way. It also handles English, so a station that lists both
/// languages is given this model.

const bilingualSpeechModel = SpeechModel(
  id: 'zipformer-small-bilingual-zh-en-2023-02-16',
  language: 'Chinese and English',
  baseUrl: 'https://dev.empwr.au/radiopod/sherpa-onnx/',
  encoder: 'encoder-epoch-99-avg-1.int8.onnx',
  decoder: 'decoder-epoch-99-avg-1.onnx',
  joiner: 'joiner-epoch-99-avg-1.int8.onnx',
  bytes: 42980793 + 13877276 + 3228485 + 56317,
);

/// Every model captions can use, for the settings screen.

const speechModels = [englishSpeechModel, bilingualSpeechModel];

/// The model for a station whose language is [language], or null when
/// captions are not offered for it.
///
/// Radio-Browser records languages as free text, lower case and comma
/// separated, and variously — "english", "american english", "english uk",
/// "chinese,english" — so the test is for the word anywhere in it rather
/// than an exact match. Chinese is tested first: the bilingual model covers
/// English too, so a station listing both is better served by it.
///
/// A station with no language recorded, as for one added by hand or
/// imported from a playlist file, gets no model: guessing would give
/// confident nonsense in the wrong language.

SpeechModel? speechModelForLanguage(String? language) {
  final l = (language ?? '').toLowerCase();
  if (l.contains('chinese') || l.contains('mandarin')) {
    return bilingualSpeechModel;
  }
  if (l.contains('english')) return englishSpeechModel;

  return null;
}

SpeechModel? speechModelFor(Station? station) =>
    station == null ? null : speechModelForLanguage(station.language);
