/// RadioAudioHandler — background playback and the Android Auto media session.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
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

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'package:radiopod/constants/app.dart';
import 'package:radiopod/models/cast.dart';
import 'package:radiopod/models/playlist.dart';
import 'package:radiopod/models/station.dart';
import 'package:radiopod/services/browse_tree.dart';
import 'package:radiopod/services/carplay_bridge.dart';
import 'package:radiopod/services/cast_playback.dart';
import 'package:radiopod/services/cast_store.dart';
import 'package:radiopod/services/focus_policy.dart';
import 'package:radiopod/services/geo_block.dart';
import 'package:radiopod/services/icy_reader.dart';
import 'package:radiopod/services/stream_end_policy.dart';
import 'package:radiopod/utils/cast_merge.dart';
import 'package:radiopod/utils/platform_io.dart'
    if (dart.library.js_interop) 'package:radiopod/utils/platform_web.dart';

part 'radio_audio_handler_casts.dart';
part 'radio_audio_handler_focus.dart';
part 'radio_audio_handler_stream_end.dart';

/// The single audio handler, shared by the Flutter UI, the system
/// notification, the lock screen, headset buttons and Android Auto.
///
/// Everything that plays audio goes through here. The UI never touches the
/// [AudioPlayer] directly, so the state the car shows and the state the app
/// shows can never disagree.
///
/// Live radio has no duration and no meaningful position, so this handler
/// deliberately does NOT mix in SeekHandler and does not offer fast-forward
/// or rewind. Stations are switched with Next and Previous instead, moving
/// through whichever playlist the station was started from.
///
/// 20261016 gjw A PODCAST'S CAST DOES HAVE A TIMELINE, so while one plays —
/// and only then — the session offers pause, seek, back 15 s and forward
/// 30 s, publishes the position, and Next and Previous move to the older or
/// newer cast. Radio is unchanged. The cast logic lives in
/// radio_audio_handler_casts.dart.

class RadioAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  /// The library, pushed in by AppProvider whenever it changes.

  List<Station> _stations = [];
  List<Playlist> _playlists = [];

  /// The stations Next and Previous move through, and where we are in them.
  ///
  /// Set from the folder the current station was started from, so the queue
  /// matches what the driver was browsing.

  List<Station> _queueStations = [];
  int _queueIndex = -1;

  /// The browse folder the current queue came from, so a skip keeps reporting
  /// the same folder in its media ids rather than silently falling back to
  /// All Stations.

  String _queueParentId = browseAllStationsId;

  /// The station on air, and the track it last announced.
  ///
  /// Both are needed to rebuild the published media item when ICY metadata
  /// arrives: the station supplies the name and logo, the track the subtitle.

  /// When the current station started, and how many stations in a row have
  /// ended too quickly to have really played. Together these stop
  /// auto-advance from becoming a loop over a queue of dead stations.

  DateTime? _startedAt;
  int _failedAdvances = 0;

  /// Runs while we wait to see whether a stream that ended comes back by
  /// itself. Non-null means an advance is pending and can still be called
  /// off. See [_onStreamEnded].

  Timer? _endTimer;

  /// True once [stop] has released the platform player, so [play] knows it
  /// has to open the station again rather than try to resume a source that
  /// is no longer loaded.

  bool _stopped = false;

  /// Counts the opens [playStation] starts, and the stops that end them.
  ///
  /// 20261022 gjw Tapping another station while one is still Connecting…
  /// interrupts the first load, which throws. That is not a station failing
  /// to connect, and reporting it put up a "could not connect" popup for a
  /// station the listener had already moved on from. An open whose number is
  /// no longer the latest returns quietly instead.

  int _openCount = 0;

  /// How long to wait for a station to open before calling it a failure.
  ///
  /// Generous, because a distant station on a slow connection is not an
  /// error. It exists only so a load that will NEVER finish cannot leave the
  /// row spinning for ever — see the use in [playStation].

  static const _openTimeout = Duration(seconds: 30);

  /// Called when playback begins while nothing was playing — a first start,
  /// or a resume after Stop or Pause, but not a switch between stations or
  /// an automatic reconnect. Player.init points it at the sleep timer.

  void Function()? onPlayFromSilence;

  /// What plays when a cast finishes, from Settings. Player.init loads it
  /// from [AfterCastPreference], so the car follows it with no screen open.

  AfterCast afterCast = AfterCast.older;

  /// Called when [stop] has silenced the player. Not called by a Pause, nor
  /// by the silence [playStation] makes between stations. Player.init points
  /// it at the sleep timer, which a stop resets.

  void Function()? onStopped;

  final _geoBlocks = StreamController<GeoBlock>.broadcast();

  /// A station that ended early because its server refuses our country.
  /// The app shows each one in a dialog — see [_reportGeoBlock].

  Stream<GeoBlock> get geoBlocks => _geoBlocks.stream;

  /// Stations whose headers have been checked this session.

  final _geoChecked = <String>{};

  Station? _currentStation;
  String? _currentTrack;

  /// The cast on air when [_currentStation] is a podcast, else null. Its
  /// listener state is the store's; this copy supplies title and length.

  Cast? _currentCast;

  /// Saves the cast's place every [castSaveEvery] while it plays.

  Timer? _castSaveTimer;

  /// True while a finished cast is handing over to the next, so a second
  /// `completed` report does not start a second hand-over.

  bool _castEnding = false;

  /// True while a cast is paused because another app's sound asked us to
  /// duck. See [FocusHandling].

  bool _pausedForOther = false;

  /// Whether the audio session is set up for speech (a cast) rather than
  /// music (a station); null until the first play sets it.

  bool? _speechSession;

  /// Looks every [focusPollEvery] for the end of another app's sound after
  /// it took the sound outright. See [FocusHandling].

  Timer? _focusPoll;

  /// The counts the car's rows last showed, to tell a change that matters
  /// to them from one that does not.

  String _lastCastCounts = '';

  /// The desktop track reader for the current station, cancelled whenever
  /// playback moves on so only one stream is ever being polled.

  StreamSubscription<String?>? _trackSubscription;

  /// The folder ids a client has subscribed to, so a library change can tell
  /// each one to re-read its children.

  final _childSubjects = <String, BehaviorSubject<Map<String, dynamic>>>{};

  RadioAudioHandler() {
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        debugPrint('[RadioAudioHandler] playback event error: $e');
      },
    );

    // 20260921 gjw playbackEventStream does not fire for every play/pause
    // transition — the processing state is unchanged when an already-buffered
    // stream is simply resumed — so the notification and the car would keep
    // showing the old transport state. Watching playingStream as well closes
    // that gap; _broadcastState reads _player.playing either way, so the
    // duplicate broadcast is harmless.

    _player.playingStream.listen((_) => _broadcastState(null));

    // 20260921 gjw Shoutcast and Icecast streams announce the song on air in
    // band, as ICY metadata, and just_audio surfaces it here. Republishing
    // the media item on each announcement is what puts the track under the
    // station name in the app, in the notification, and on the car's
    // now-playing screen.

    _player.icyMetadataStream.listen(_broadcastTrack);

    _watchCasts();
    unawaited(_watchFocus());

    // 20260922 gjw Most internet radio is an endless stream, but not all of
    // it: NPR and other bulletin feeds genuinely END when the bulletin is
    // over, and a dropped connection arrives here the same way, because
    // setUrl has long since returned by the time it fails. Either way,
    // sitting on a finished stream is the wrong thing — move to the next
    // station, as Transistor does.

    // 20260923 gjw `s.playing` is part of the test, not decoration. When a
    // live source genuinely runs out just_audio leaves playing TRUE and only
    // moves the processing state to completed — see [_resumed]. A completed
    // arriving with playing FALSE is therefore not a station ending; it is
    // the player being torn down or swapped, and acting on it auto-stopped
    // the station a few seconds after every manual Stop then Play.

    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && s.playing) {
        // A cast that reaches its end has been heard; a stream that does has
        // dropped or finished, which is a different question entirely.

        _currentCast != null ? unawaited(_onCastEnded()) : _onStreamEnded();
      } else if (_resumed) {
        // The stream picked itself back up. Call off any pending advance.

        _cancelPendingAdvance();
      }
    });
  }

  /// True when the player is actually producing audio again.
  ///
  /// Note that `playing` alone is NOT enough: just_audio leaves `playing`
  /// true when a source runs out, and only moves `processingState` to
  /// completed. Both have to be checked.

  bool get _resumed =>
      _player.playing &&
      _player.processingState != ProcessingState.completed &&
      _player.processingState != ProcessingState.idle;

  // ── Library ───────────────────────────────────────────────────────────────

  /// Replace the library the browse tree is built from.
  ///
  /// Called on every load from the Pod and on every edit, so a station added
  /// on the phone shows up in the car without a restart.

  void setLibrary(List<Station> stations, List<Playlist> playlists) {
    _stations = stations;
    _playlists = playlists;

    // Nudge every subscribed folder. The value is the subscription options
    // map, which we do not use; it is the notification itself that matters.

    for (final entry in _childSubjects.entries) {
      entry.value.add(<String, dynamic>{});
    }

    // 20260929 tc CarPlay does not browse through audio_service, so its
    // native lists are handed the same library here.

    CarPlayBridge.publishLibrary(
      stations,
      playlists,
      detailsOf: _podcastDetails,
    );
    _lastCastCounts = _castCounts();
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Start [station], with Next and Previous moving through [queue].
  ///
  /// [queue] is the list the station was picked from — a playlist, a filtered
  /// view, or just the one station. Passing it explicitly keeps the skip
  /// behaviour the same whether playback started in the app or in the car.

  ///
  /// For a podcast, [castGuid] names the cast to play; otherwise the newest
  /// still to hear. Throws [NothingToPlay] when the podcast has none left.

  Future<void> playStation(
    Station station, {
    List<Station>? queue,
    String parentId = browseAllStationsId,
    String? castGuid,
  }) async {
    // Read BEFORE _silence() below, which leaves the player not playing
    // even when this is a switch from one station to another.

    final fromSilence = !_player.playing;
    final open = ++_openCount;

    // Resolve the cast first, so a podcast with nothing left to play fails
    // before the station on air is disturbed. Then save the place in
    // whatever cast is being left.

    final cast = station.isPodcast ? _castToPlay(station, castGuid) : null;
    await _saveCastPlace();
    _castSaveTimer?.cancel();

    _queueStations = (queue == null || queue.isEmpty) ? [station] : queue;
    _queueParentId = parentId;
    _queueIndex = _queueStations.indexWhere((s) => s.id == station.id);
    if (_queueIndex < 0) {
      _queueStations = [station];
      _queueIndex = 0;
    }

    // Forget the previous station's track before the new stream announces
    // its own, so a switch never leaves the old song showing under the new
    // station's name.

    _currentStation = station;
    _currentTrack = null;
    _currentCast = cast;
    _castEnding = false;
    _pausedForOther = false;
    _focusPoll?.cancel();
    _startedAt = DateTime.now();
    _stopped = false;

    // Any advance still pending for the station we are leaving belongs to
    // that station, not this one.

    _cancelPendingAdvance();
    _watchTrack(station);

    _publishQueue();
    mediaItem.add(_nowItem());

    try {
      // Silence whatever is on BEFORE opening the next station.
      //
      // setUrl is supposed to replace the media by itself, and on native
      // platforms it does. On the web just_audio drives a single shared
      // <audio> element, and assigning a new src to one that still holds a
      // live stream is not a reliable reset: the old station carried on
      // while the row already showed the new one as playing. Pausing first
      // was not enough either — a paused element still holds its stream —
      // so this uses the same full reset that Stop does.

      await _silence();

      // A live stream has no duration, and just_audio's web backend waits on
      // a durationchange event to decide a load has finished. That event can
      // simply never arrive, which left the row spinning on "Connecting…"
      // with no way back. Failing is better than hanging: the row can then
      // show the error and be tapped again.

      // A cast resumes where the listener left it, unless it was heard to
      // the end and is being played again on purpose.

      await _player
          .setUrl(
            cast?.audioUrl ?? station.url,
            initialPosition: cast == null || cast.played
                ? null
                : resumeFrom(cast.position),
          )
          .timeout(_openTimeout);

      // Another station, or a Stop, came along while this one loaded.

      if (open != _openCount) return;

      // 20261013 gjw BEFORE play(), not after: just_audio's play() future
      // completes only when playback later pauses or stops.

      if (cast != null) _startCastSaving();
      if (fromSilence) onPlayFromSilence?.call();
      await _useSessionFor(speech: cast != null);
      await _player.play();
    } catch (e) {
      // Superseded, not failed: the newer open owns the playback state.

      if (open != _openCount) {
        debugPrint('[RadioAudioHandler] ${station.name} superseded: $e');

        return;
      }
      debugPrint('[RadioAudioHandler] cannot play ${station.url}: $e');
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          playing: false,
        ),
      );

      rethrow;
    }
  }

  /// Start playing again after a stop.
  ///
  /// RE-OPENS THE STATION RATHER THAN RESUMING. just_audio's `stop()` tears
  /// the platform player down, and its `play()` then brings a new one up and
  /// reloads the source with the position the old one had reached:
  ///
  ///     initialSeekValues = (index: currentIndex, position: position)
  ///
  /// For a file that restores where you were. For LIVE RADIO there is
  /// nothing to seek to, and libmpv refuses outright — "Cannot seek in this
  /// stream" — leaving a player that reports itself as playing while no
  /// audio arrives. Opening the URL afresh starts at the live edge, which is
  /// the only thing a resumed radio station could sensibly mean anyway.

  @override
  Future<void> play() async {
    final station = _currentStation;
    if (_stopped && station != null) {
      await playStation(
        station,
        queue: _queueStations,
        parentId: _queueParentId,
        castGuid: _currentCast?.guid,
      );

      return;
    }

    if (!_player.playing) onPlayFromSilence?.call();

    // A paused cast picks up a few seconds back, so the listener does not
    // come in mid-word. See [castResumeBack].

    if (_currentCast != null && !_player.playing) {
      await _player.seek(resumeFrom(_player.position));
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    await _saveCastPlace();
  }

  @override
  Future<void> seek(Duration position) => _seekCast(position);

  @override
  Future<void> fastForward() => _seekCast(_player.position + castSkipForward);

  @override
  Future<void> rewind() => _seekCast(_player.position - castSkipBack);

  /// Set the volume from 0 to 1, for the sleep timer's fade. It carries
  /// over a change of station, which is what lets a fade continue across
  /// one.

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  /// Silence the player the way this platform needs.
  ///
  /// Shared by [stop] and by [playStation], because switching station has
  /// exactly the same requirement as stopping: whatever was on must be gone
  /// BEFORE the next URL is opened. Having the two do different things is
  /// what let the previous station keep playing under the new one's name.
  ///
  /// See [stopByPause] for why libmpv pauses while everything else stops.

  Future<void> _silence() => stopByPause ? _player.pause() : _player.stop();

  @override
  Future<void> stop() async {
    // 20260923 gjw ON LIBMPV, STOP PAUSES RATHER THAN TEARING THE PLAYER
    // DOWN. Elsewhere it really stops. See [stopByPause].
    //
    // just_audio's own stop() disposes the platform player, and bringing one
    // back up reloads the source at the position the old one reached — which
    // a live stream cannot seek to, so playback came back silent. Worse, the
    // teardown itself emits a completed state that the stream-end listener
    // above read as "the station finished", stopping it again seconds after
    // every Stop then Play. On Linux the libmpv dispose is also slow enough
    // to leave the button looking dead, and is a likely source of the crash
    // on quit.
    //
    // 20260924 gjw That was first applied to every platform, which was too
    // broad. The seek complaint no longer applies anywhere, because [play]
    // re-opens the station rather than resuming it, and the completed state
    // is caught by the guards in the listener and in _onStreamEnded. What
    // remains is a libmpv concession.
    //
    // On the web pausing was actively wrong. The browser gives just_audio one
    // shared audio element, so a paused element still holds the previous
    // stream: the old station stayed audible, and loading the next one into
    // it waited on a durationchange event that a live stream never fires,
    // leaving the row on "Connecting…" indefinitely.
    //
    // A real stop also drops the connection, which is what a listener means
    // by Stop. Pausing keeps it open until the next play.

    // _stopped is set BEFORE silencing, not after. _silence() makes the
    // player go idle, the event listener reads _stopped to tell a real stop
    // from a station switch, and setting it afterwards left that listener
    // reporting a switch for the one case that genuinely is a stop.

    // Keep the place in a cast before the player lets go of it.

    await _saveCastPlace();
    _castSaveTimer?.cancel();

    _stopped = true;
    _openCount++;
    await _silence();

    // After the silence, so a timer cancelled mid-fade restores the volume
    // only once nothing is left to hear.

    onStopped?.call();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );

    // Stop polling the stream the moment playback stops, so a stopped app is
    // not quietly still fetching from a station in the background.

    await _trackSubscription?.cancel();
    _trackSubscription = null;

    // A stop ends the current run, so the next thing the user starts gets a
    // full set of auto-advance attempts rather than inheriting the tally
    // from a queue of stations that would not play.

    _failedAdvances = 0;
    _startedAt = null;

    // A deliberate stop must not be followed moments later by an advance
    // that was already in flight.

    _cancelPendingAdvance();

    await super.stop();
  }

  /// Republish the current media item with the track [icy] announces.
  ///
  /// NOT AVAILABLE ON EVERY PLATFORM. just_audio_media_kit reports
  /// `icyMetadata: null` unconditionally, so on Linux and Windows desktop
  /// this never fires and the subtitle stays on the station's own details.
  /// Plenty of streams on the supported platforms send nothing either, or
  /// send their own station name rather than a song, so the UI must always
  /// read as correct with no track at all.

  void _broadcastTrack(IcyMetadata? icy) => _setTrack(icy?.info?.title);

  /// Publish [title] as the song on air, ignoring a repeat of what is already
  /// showing so the media session is not churned on every poll.

  void _setTrack(String? title) {
    final station = _currentStation;

    // A cast's title is its track; anything a podcast host embeds as ICY
    // metadata is not wanted over it.

    if (station == null || _currentCast != null) return;

    final track = _cleanTrack(title);
    if (track == _currentTrack) return;

    _currentTrack = track;
    mediaItem.add(_nowItem());
    _publishQueue();
  }

  /// Publish the queue, with the station now playing carrying EXACTLY what
  /// [mediaItem] carries.
  ///
  /// 20261006 gjw Android's Bluetooth stack will not hand the car anything
  /// until the session's metadata agrees with the queue row named by the
  /// active queue id. When they disagree it waits, and then gives up:
  ///
  ///     E MediaPlayerWrapper: Timeout while waiting for metadata to sync
  ///       Current Metadata: title="Celine Dion" artist="Celine Dion - ..."
  ///       QueueItem(7):     title="Celine Dion" artist="The United Arab ..."
  ///
  /// They could never agree. The now-playing item puts the song on air in
  /// the artist slot (CLAUDE.md §11) and prefers the user's chosen icon for
  /// artwork, while the queue was built from plain [stationMediaItem] calls
  /// carrying the station's codec-and-bitrate subtitle and its own logo. So
  /// the SAME station appeared twice, described two different ways, and
  /// every station change and every song change cost a ten second stall.
  ///
  /// The row that is playing is therefore the same item the session
  /// publishes. The rest stay as the browse tree builds them — only the
  /// active one is reconciled, and only it has a track to carry.

  void _publishQueue() {
    final items = [
      for (final s in _queueStations)
        stationMediaItem(s, _queueParentId, details: _podcastDetails(s)),
    ];

    if (_currentStation != null &&
        _queueIndex >= 0 &&
        _queueIndex < items.length) {
      items[_queueIndex] = _nowItem();
    }

    // An unchanged queue is not republished. Skipping within a playlist
    // changes which row is active and nothing else, and handing the car a
    // fresh list makes it tear down and rebuild the whole now-playing list.
    //
    // Compared field by field, NOT with listEquals: MediaItem's == is id
    // only (audio_service.dart:667), so a changed artist or artwork — the
    // very thing this republishes for — would compare equal.

    if (_queueSignature(items) == _queueSignature(queue.value)) return;

    queue.add(items);
  }

  static String _queueSignature(List<MediaItem> items) => items
      .map((i) => '${i.id}\u0000${i.artist}\u0000${i.artUri}')
      .join('\u0001');

  /// Start (or restart) reading the song on air for [station].
  ///
  /// Only runs where the player itself reports nothing — GNU/Linux and
  /// Windows, where just_audio_media_kit hardcodes `icyMetadata: null`.
  /// Everywhere else [_broadcastTrack] is already being fed by the player on
  /// the connection it has open, and polling would be pure waste.

  void _watchTrack(Station station) {
    _trackSubscription?.cancel();
    _trackSubscription = null;
    if (!needsIcyPolling || !icyPollingEnabled || station.isPodcast) return;

    _trackSubscription = IcyReader.watch(station.url).listen(
      (title) {
        // Ignore a late result for a station the user has already left.

        if (_currentStation?.id == station.id) _setTrack(title);
      },
      onError: (Object e) {
        debugPrint('[RadioAudioHandler] track reader error: $e');
      },
    );
  }

  /// Tidy an ICY title, mapping anything useless to null.
  ///
  /// Stations pad titles with whitespace, and a good number send the station
  /// name or a placeholder when nothing is playing. Echoing the station name
  /// back under itself looks broken, so that case falls through to the
  /// station details instead.

  String? _cleanTrack(String? title) {
    final t = title?.trim();
    if (t == null || t.isEmpty) return null;
    if (t.toLowerCase() == _currentStation?.name.trim().toLowerCase()) {
      return null;
    }

    return t;
  }

  /// Next and Previous: through the station queue, a podcast included.
  ///
  /// 20261023 gjw While a cast played they used to walk its episodes, and
  /// were offered only when there was another to hear, so Next in the car
  /// seemed to stop at a podcast. A driver pressing Next wants the next
  /// station; episodes are chosen from the podcast's Episodes page.

  @override
  Future<void> skipToNext() => _skipBy(1);

  @override
  Future<void> skipToPrevious() => _skipBy(-1);

  /// Move [delta] stations through the current queue, wrapping at the ends.
  ///
  /// Wrapping matters in the car: a driver pressing Next on the last station
  /// should land back at the first rather than have nothing happen.

  ///
  /// 20261023 gjw A podcast with no episode left to hear is PASSED OVER, as
  /// [_advanceFromPodcast] passes it. Next used to stop at it with nothing
  /// to say, and in the car that looked like the button had broken. Only
  /// that is passed over: a station that will not connect still reports
  /// its error, since the driver should hear that it is gone.

  Future<void> _skipBy(int delta) async {
    if (_queueStations.length < 2 || _queueIndex < 0) return;

    final queue = _queueStations;
    final from = _queueIndex;
    final n = queue.length;

    for (var step = 1; step < n; step++) {
      try {
        await playStation(
          queue[(from + delta * step + n * step) % n],
          queue: queue,
          parentId: _queueParentId,
        );

        return;
      } on NothingToPlay catch (e) {
        debugPrint('[RadioAudioHandler] passing over ${e.podcast}');
      }
    }
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final parts = splitStationMediaId(mediaId);
    if (parts == null) return;

    final station = _stations.where((s) => s.id == parts.stationId).firstOrNull;
    if (station == null) return;

    // Rebuild the folder the driver was browsing so Next and Previous stay
    // inside it.

    final siblings = browseChildren(parts.parentId, _stations, _playlists)
        .map((m) => m.extras?['stationId'] as String?)
        .whereType<String>()
        .map((id) => _stations.where((s) => s.id == id).firstOrNull)
        .whereType<Station>()
        .toList();

    await playStation(station, queue: siblings, parentId: parts.parentId);
  }

  // ── Browsing (Android Auto) ───────────────────────────────────────────────

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async => browseChildren(
    parentMediaId,
    _stations,
    _playlists,
    detailsOf: _podcastDetails,
  );

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) =>
      _childSubjects
          .putIfAbsent(
            parentMediaId,
            () => BehaviorSubject<Map<String, dynamic>>.seeded(
              <String, dynamic>{},
            ),
          )
          .stream;

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final parts = splitStationMediaId(mediaId);
    if (parts == null) return null;
    final station = _stations.where((s) => s.id == parts.stationId).firstOrNull;

    return station == null
        ? null
        : stationMediaItem(
            station,
            parts.parentId,
            details: _podcastDetails(station),
          );
  }

  // ── State broadcast ───────────────────────────────────────────────────────

  /// Publish just_audio's state as a media session state.
  ///
  /// Stop rather than Pause is offered while playing: pausing a live stream
  /// only leaves a stalled buffer to resume from, so stopping and restarting
  /// is the honest control. Position and buffered position are left at zero
  /// because a live stream has no timeline to show.
  ///
  /// The event is not read — everything comes from the player itself — so it
  /// is nullable, letting playingStream call this too.

  void _broadcastState(PlaybackEvent? event) {
    final playing = _player.playing;
    if (_currentCast != null) return _broadcastCastState(playing);

    final hasQueue = _queueStations.length > 1;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (hasQueue) MediaControl.skipToPrevious,
          if (playing) MediaControl.stop else MediaControl.play,
          if (hasQueue) MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.play, MediaAction.stop},
        androidCompactActionIndices: hasQueue ? const [0, 1, 2] : const [0],
        processingState: _reportedState,
        playing: playing,
        queueIndex: _queueIndex < 0 ? null : _queueIndex,

        // Back to no timeline, should a cast have published one.
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );
  }

  /// The player's state as the media session should hear it. The rule is
  /// [reportedProcessingState] at the foot of this file, and it matters.

  AudioProcessingState get _reportedState => reportedProcessingState(
    _processingState[_player.processingState]!,
    stopped: _stopped,
    hasStation: _currentStation != null,
  );

  static const _processingState = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };
}

/// The media item for the session, with artwork only where it can be seen.
///
/// 20261005 gjw On GNU/Linux and Windows audio_service is NoOpAudioService
/// (CLAUDE.md §2) and on the web the artwork fetch hits the CORS wall, so in
/// all three cases nothing displays the image. audio_service downloads every
/// non-file artUri through flutter_cache_manager BEFORE reaching the
/// platform, so each station change pulled an image that could not be shown,
/// and printed an unsilenceable stack trace whenever a station's logo host
/// was dead — a 402 from a lapsed Firebase bucket, for one.
///
/// The decision lives HERE rather than in stationMediaItem because that is a
/// pure function with its own tests: gating it there made the browse tree
/// platform-dependent and the tests failed on the host that ran them.
///
/// The app's own station list is unaffected; it loads logos through
/// Image.network and still shows them.

MediaItem _sessionItem(Station station, String parentId, {String? track}) {
  final item = stationMediaItem(station, parentId, track: track);

  // 20261006 gjw Nothing more to do about WHICH image: stationMediaItem now
  // picks a chosen icon over the station logo for every surface, so this is
  // only the platform gate above.

  return showsMediaArt ? item : item.copyWith(artUri: null);
}

/// What the media session should be told, given the player's [state].
///
/// Pure, and public, so the rule below can be tested without a media
/// session — the same reason [decideStreamEnd] lives apart from the handler.
/// Getting it wrong costs nothing a desktop or a phone would show and breaks
/// the car, which is the hardest place to notice anything.
///
/// IDLE IS NOT A STATE WE MAY PASS THROUGH. audio_service reads any
/// transition into it as the session being finished:
///
///     if (oldProcessingState != idle && processingState == idle) {
///         stop();                  // AudioService.java:565
///     }
///
/// and that `stop()` is `deactivateMediaSession(); stopSelf();`
/// (AudioService.java:355) — the whole media service goes down.
///
/// Changing station goes through idle on the way. playStation calls
/// _silence(), which on everything but libmpv is a real `_player.stop()`,
/// and just_audio reports idle until the next URL is open. So EVERY skip
/// tore the service down and built it back up. On the phone that is a
/// notification that blinks; in the car the now-playing screen loses its
/// session and Android Auto drops the driver back to the station list —
/// exactly the "momentarily shows the next station, then crashes back to
/// the list" that pressing Next produced. It is also why logcat showed
/// `No process com.togaware.radiopod ... for service AudioService` with no
/// fatal exception anywhere: nothing crashed, the service was asked to stop.
///
/// So idle is reported only when playback really is finished — [stopped]
/// after the user presses Stop, and no station at all before the first one
/// plays. A switch reports `loading`, which is the truth and reaches the car
/// as STATE_CONNECTING (AudioService.java:604).
///
/// 20261013 gjw The other way round too: a STOP that is really a pause
/// (libmpv, see stopByPause) leaves the player `ready`, which read as
/// Paused, so the Stop button stayed Stop rather than offering Play. It
/// also raced the idle that stop() pushes, so a second tap sometimes
/// showed Play and sometimes did not. After a stop, ready is reported as
/// idle. Elsewhere a stop is real and the player is idle anyway.

AudioProcessingState reportedProcessingState(
  AudioProcessingState state, {
  required bool stopped,
  required bool hasStation,
}) {
  if (stopped && state == AudioProcessingState.ready) {
    return AudioProcessingState.idle;
  }
  if (state != AudioProcessingState.idle) return state;
  if (stopped || !hasStation) return state;

  return AudioProcessingState.loading;
}
