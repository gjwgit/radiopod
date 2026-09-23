/// IcyReader — read the song on air straight from the stream, for desktop.
///
// Time-stamp: <Sunday 2026-09-21 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

/// Pulls the ICY `StreamTitle` out of a Shoutcast or Icecast stream.
///
/// WHY THIS EXISTS. On Android, iOS and macOS just_audio reports ICY metadata
/// itself and none of this runs. On GNU/Linux and Windows playback goes
/// through just_audio_media_kit, which reports `icyMetadata: null`
/// unconditionally — the field is hardcoded in its `_updatePlaybackEvent`, so
/// there is nothing to wait for and no setting that changes it. Without this
/// reader the desktop builds could never show a track title at all.
///
/// It POLLS rather than streams. A second continuous connection purely to
/// read titles would download the whole stream twice — some 24 KB/s for a
/// 192 kbps station. Instead each poll connects, reads just far enough to see
/// one metadata block, and hangs up: roughly 16 KB every [_pollInterval],
/// well under a kilobyte per second, at the cost of noticing a track change a
/// few seconds late. For a listener glancing at a now-playing bar that is the
/// right trade.

/// Whether to read track titles by polling the stream.
///
/// 20260922 gjw This was turned OFF for one build to test whether opening a
/// second connection to a playing stream was what cut ABC News Radio off
/// every 40 to 50 seconds. IT WAS NOT: with polling disabled the dropouts
/// continued, and settled to a reliable 50 seconds. The real cause was ABC
/// being served over HLS — see [Station.isHls]. Polling is back on, and this
/// switch stays as the quickest way to rule it out again.

const icyPollingEnabled = true;

class IcyReader {
  IcyReader._();

  /// How long between polls. Long enough to be cheap, short enough that the
  /// bar is not obviously stale on a three-minute song.

  static const _pollInterval = Duration(seconds: 25);

  /// Give up on one poll after this. A stalled connection must not wedge the
  /// poller, and the next tick will try again anyway.

  static const _timeout = Duration(seconds: 15);

  /// Stop reading a poll after this many bytes even if no title has appeared,
  /// so a station with a huge metadata interval cannot pull down megabytes.

  static const _byteBudget = 96 * 1024;

  static const _userAgent =
      'RadioPod/1.0.17 (+https://github.com/gjwgit/radiopod)';

  /// Emit the song on air for [url], repeatedly, until the subscription is
  /// cancelled.
  ///
  /// Emits null when the title becomes unknown. Completes early and silently
  /// when the station serves no ICY metadata at all, which is common — there
  /// is no point polling a stream that will never answer.

  static Stream<String?> watch(String url) async* {
    while (true) {
      final result = await _poll(url);
      if (result.unsupported) return;

      yield result.title;
      await Future<void>.delayed(_pollInterval);
    }
  }

  /// One connect-read-hangup cycle.

  static Future<({String? title, bool unsupported})> _poll(String url) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..headers['Icy-MetaData'] = '1'
        ..headers['User-Agent'] = _userAgent;

      final response = await client.send(request).timeout(_timeout);
      if (response.statusCode != 200) {
        return (title: null, unsupported: true);
      }

      // icy-metaint is how many bytes of audio sit between metadata blocks.
      // Its absence means the station does not speak ICY at all.

      final interval = int.tryParse(
        response.headers['icy-metaint'] ??
            response.headers['Icy-MetaInt'] ??
            '',
      );
      if (interval == null || interval <= 0) {
        return (title: null, unsupported: true);
      }

      final title = await _firstTitle(
        response.stream,
        interval,
      ).timeout(_timeout);

      return (title: title, unsupported: false);
    } catch (e) {
      debugPrint('[IcyReader] poll failed for $url: $e');

      // A failure is not proof the station lacks metadata — the network may
      // simply have dropped — so keep polling.

      return (title: null, unsupported: false);
    } finally {
      // Hanging up is what keeps this cheap. Without it the audio would keep
      // arriving on a connection nothing is listening to.

      client.close();
    }
  }

  /// Read [body] until the first non-empty metadata block yields a title.
  ///
  /// A zero-length block means "unchanged since the last one", which a server
  /// may well send first, so several blocks are read before giving up.

  static Future<String?> _firstTitle(
    Stream<List<int>> body,
    int interval,
  ) async {
    final parser = IcyStreamParser(interval);

    await for (final chunk in body) {
      final title = parser.feed(chunk);
      if (title != null) return title;
      if (parser.bytesRead > _byteBudget) break;
    }

    return null;
  }
}

/// Incremental parser for the ICY byte protocol.
///
/// The body of a metadata-enabled stream is a repeating pattern: [interval]
/// bytes of audio, one length byte holding the metadata size divided by 16,
/// then that many bytes of metadata, null-padded. Chunks from the socket fall
/// anywhere within that pattern, so the position has to be carried between
/// them — hence a class rather than a function.
///
/// Separated out from [IcyReader] so the protocol can be tested without a
/// network.

class IcyStreamParser {
  IcyStreamParser(this.interval) : _audioLeft = interval;

  /// Bytes of audio between metadata blocks, from the `icy-metaint` header.

  final int interval;

  /// Total bytes consumed, so a caller can enforce a budget.

  int bytesRead = 0;

  int _audioLeft;
  int _metaLeft = 0;
  bool _needLengthByte = false;
  final _meta = <int>[];

  /// Feed one chunk, returning a title as soon as a complete block holds one.

  String? feed(List<int> chunk) {
    bytesRead += chunk.length;
    var i = 0;

    while (i < chunk.length) {
      if (_audioLeft > 0) {
        final skip = math.min(_audioLeft, chunk.length - i);
        _audioLeft -= skip;
        i += skip;
        if (_audioLeft == 0) _needLengthByte = true;
        continue;
      }

      if (_needLengthByte) {
        _metaLeft = chunk[i] * 16;
        i++;
        _needLengthByte = false;
        _meta.clear();

        // A zero-length block says nothing changed; wait for the next one.

        if (_metaLeft == 0) _audioLeft = interval;
        continue;
      }

      final take = math.min(_metaLeft - _meta.length, chunk.length - i);
      _meta.addAll(chunk.sublist(i, i + take));
      i += take;

      if (_meta.length < _metaLeft) continue;

      _audioLeft = interval;
      final title = streamTitleFrom(utf8.decode(_meta, allowMalformed: true));
      if (title != null) return title;
    }

    return null;
  }
}

/// Extract `StreamTitle` from a decoded ICY metadata block.
///
/// The block looks like `StreamTitle='Chris Rea - On The Beach';StreamUrl='';`
/// padded with nulls. Single quotes inside a title are not escaped by the
/// protocol, so the terminator is matched as `';` — a quote followed by a
/// semicolon — rather than the first quote, and a block with no terminator
/// falls back to the end of the string.

String? streamTitleFrom(String block) {
  const key = "StreamTitle='";
  final start = block.indexOf(key);
  if (start < 0) return null;

  final from = start + key.length;
  final end = block.indexOf("';", from);
  final raw = end < 0 ? block.substring(from) : block.substring(from, end);
  final title = raw.replaceAll('\u0000', '').trim();

  return title.isEmpty ? null : title;
}
