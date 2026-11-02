/// Caption engine — the speech model on disk, and the recogniser that runs it.
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

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:radio_pcm/radio_pcm.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:radiopod/services/captions/speech_model.dart';

/// Where a downloaded model lives, and the download itself.
///
/// Models go in Application Support rather than Caches, so iOS does not
/// quietly delete them under storage pressure and leave captions asking for
/// a download again. They are excluded from the device backup instead: they
/// can always be fetched again, and 45 MB of someone's iCloud is not ours to
/// spend.

class SpeechModelStore {
  SpeechModelStore._();

  /// Written last, so a download that was interrupted is never mistaken for
  /// a complete one.

  static const _marker = '.complete';

  static Future<Directory> _dir(SpeechModel model) async {
    final support = await getApplicationSupportDirectory();

    return Directory('${support.path}/speech_models/${model.id}');
  }

  static Future<bool> isInstalled(SpeechModel model) async =>
      File('${(await _dir(model)).path}/$_marker').exists();

  /// Fetch every file of [model], reporting overall progress from 0 to 1.
  ///
  /// Each file is written to a `.part` name and renamed once its length
  /// matches what the server promised, so a dropped connection leaves nothing
  /// that looks usable. [cancelled] is polled between chunks.

  static Future<void> download(
    SpeechModel model, {
    required void Function(double progress) onProgress,
    required bool Function() cancelled,
  }) async {
    final dir = await _dir(model);
    await dir.create(recursive: true);

    final client = http.Client();
    var received = 0;
    try {
      for (final name in model.files) {
        final response = await client.send(
          http.Request('GET', model.uriOf(name)),
        );
        if (response.statusCode != 200) {
          throw HttpException(
            'The model server answered with HTTP ${response.statusCode}.',
          );
        }

        final part = File('${dir.path}/$name.part');
        final sink = part.openWrite();
        var written = 0;
        try {
          await for (final chunk in response.stream) {
            if (cancelled()) throw const _Cancelled();
            sink.add(chunk);
            written += chunk.length;
            received += chunk.length;
            onProgress((received / model.bytes).clamp(0, 1).toDouble());
          }
        } finally {
          await sink.close();
        }

        final expected = response.contentLength;
        if (expected != null && expected != written) {
          throw const HttpException('The model download was cut short.');
        }
        await part.rename('${dir.path}/$name');
      }

      await File('${dir.path}/$_marker').writeAsString(model.id);
      await RadioPcm.excludeFromBackup(dir.path);
    } on _Cancelled {
      await delete(model);
    } finally {
      client.close();
    }
  }

  static Future<void> delete(SpeechModel model) async {
    final dir = await _dir(model);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static Future<Map<String, String>> _paths(SpeechModel model) async {
    final d = (await _dir(model)).path;

    return {
      'encoder': '$d/${model.encoder}',
      'decoder': '$d/${model.decoder}',
      'joiner': '$d/${model.joiner}',
      'tokens': '$d/${model.tokens}',
    };
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Something the recogniser heard.
///
/// A partial result is the utterance so far and will be revised as more
/// audio arrives; a final one is settled, and the next result starts afresh.

class RecognisedText {
  final String text;
  final bool isFinal;

  const RecognisedText(this.text, {required this.isFinal});
}

/// A streaming recogniser running in its own isolate.
///
/// OFF THE UI ISOLATE because decoding is a synchronous FFI call. Even the
/// small model takes long enough per chunk to drop frames if it ran where
/// the list scrolls. Samples are passed across as TransferableTypedData, so
/// the only copy is the one the platform channel already made.

class Recogniser {
  Recogniser._(this._isolate, this._send, this._port, this._results);

  final Isolate _isolate;
  final SendPort _send;
  final ReceivePort _port;
  final StreamController<RecognisedText> _results;

  /// Everything recognised, in order.

  Stream<RecognisedText> get results => _results.stream;

  static Future<Recogniser> start(SpeechModel model) async {
    final paths = await SpeechModelStore._paths(model);
    final port = ReceivePort();
    final isolate = await Isolate.spawn(
      _recogniserMain,
      (port.sendPort, paths),
      debugName: 'captions',
      onError: port.sendPort,
    );

    final ready = Completer<SendPort>();
    final results = StreamController<RecognisedText>.broadcast();

    port.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
      } else if (message is (String, bool)) {
        results.add(RecognisedText(message.$1, isFinal: message.$2));
      } else if (message is List && !ready.isCompleted) {
        // An uncaught error before the recogniser was up: most likely a
        // model file that is missing or corrupt.

        ready.completeError(StateError('${message.first}'));
      } else if (message is String && !ready.isCompleted) {
        ready.completeError(StateError(message));
      }
    });

    try {
      final send = await ready.future.timeout(const Duration(seconds: 30));

      return Recogniser._(isolate, send, port, results);
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      port.close();
      await results.close();
      rethrow;
    }
  }

  void accept(Float32List samples) =>
      _send.send(TransferableTypedData.fromList([samples]));

  /// Forget the utterance in progress, as when the station changes.

  void reset() => _send.send('reset');

  void close() {
    _send.send('close');
    _port.close();
    unawaited(_results.close());

    // The worker frees the native recogniser and exits by itself; this is
    // only the backstop should it be stuck in a decode.

    Future<void>.delayed(
      const Duration(seconds: 2),
      () => _isolate.kill(priority: Isolate.immediate),
    );
  }
}

/// The worker isolate.
///
/// Endpoint rules are shorter than the sherpa-onnx defaults for the third
/// rule: broadcast speech rarely pauses, and a caption line that runs on for
/// twenty seconds is too long to read. Twelve seconds keeps lines to a
/// couple of sentences.

void _recogniserMain((SendPort, Map<String, String>) boot) {
  final (reply, paths) = boot;

  final sherpa.OnlineRecognizer recogniser;
  try {
    sherpa.initBindings();
    recogniser = sherpa.OnlineRecognizer(
      sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: paths['encoder']!,
            decoder: paths['decoder']!,
            joiner: paths['joiner']!,
          ),
          tokens: paths['tokens']!,
          numThreads: 2,
          modelType: 'zipformer',
          debug: false,
        ),
        rule3MinUtteranceLength: 12,
      ),
    );
  } catch (e) {
    reply.send('The speech model could not be loaded: $e');

    return;
  }

  var stream = recogniser.createStream();
  var last = '';
  final inbox = ReceivePort();
  reply.send(inbox.sendPort);

  inbox.listen((message) {
    if (message is TransferableTypedData) {
      final samples = message.materialize().asFloat32List();
      stream.acceptWaveform(samples: samples, sampleRate: RadioPcm.sampleRate);
      while (recogniser.isReady(stream)) {
        recogniser.decode(stream);
      }

      final text = recogniser.getResult(stream).text.trim();
      final endpoint = recogniser.isEndpoint(stream);

      if (endpoint) {
        if (text.isNotEmpty) reply.send((text, true));
        recogniser.reset(stream);
        last = '';
      } else if (text != last) {
        reply.send((text, false));
        last = text;
      }
    } else if (message == 'reset') {
      stream.free();
      stream = recogniser.createStream();
      last = '';
    } else if (message == 'close') {
      stream.free();
      recogniser.free();
      inbox.close();
      debugPrint('[Recogniser] closed');
    }
  });
}
