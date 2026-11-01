/// Audio focus for RadioAudioHandler: give way to other sound, then resume.
///
// Time-stamp: <Friday 2026-10-23 10:00:00 +1100 Graham Williams>
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

part of 'radio_audio_handler.dart';

/// How playback meets other apps' sound.
///
/// 20261023 gjw A STATION DUCKS, A CAST PAUSES. Radio is music, and quieter
/// music under a navigation prompt or a message is right. A cast is speech,
/// and speech under speech is lost. But as a music session Android ducks a
/// cast itself and never tells the app, so it talked on underneath.
///
/// So the session is configured for SPEECH while a cast plays, which sets
/// `willPauseWhenDucked` and makes Android hand the duck to the app; the
/// cast pauses, and resumes when the other sound ends.
///
/// A SHORT interruption (a call) is just_audio's own: it pauses the player
/// and resumes it when Android gives the sound back.
///
/// A FULL loss (another app taking the sound outright, as YouTube, Spotify
/// and many messaging apps do even for a voice message) gets no word when
/// the other sound ends: audio_session abandons our focus on the loss
/// (AndroidAudioManager.kt:353). just_audio pauses and never resumes. So
/// here we LOOK, every [focusPollEvery], whether other music is still
/// playing, and resume once it has stopped; see [focusWaitStep] for when we
/// give up. A station is reopened at the live edge, since its connection may
/// have died while paused; a cast picks up a few seconds back.

extension FocusHandling on RadioAudioHandler {
  /// Listen for other apps' sound.

  Future<void> _watchFocus() async {
    try {
      final session = await AudioSession.instance;
      session.interruptionEventStream.listen(_onFocus);
    } catch (e) {
      debugPrint('[RadioAudioHandler] no audio session: $e');
    }
  }

  void _onFocus(AudioInterruptionEvent event) {
    if (event.begin) {
      if (!_player.playing) return;
      if (_currentCast != null) unawaited(_saveCastPlace());

      switch (event.type) {
        case AudioInterruptionType.duck:
          if (_currentCast == null) return;
          _pausedForOther = true;
          unawaited(pause());
        case AudioInterruptionType.unknown:
          _waitForQuiet();
        case AudioInterruptionType.pause:
          break;
      }

      return;
    }

    if (event.type == AudioInterruptionType.duck && _pausedForOther) {
      _pausedForOther = false;
      if (!_stopped && !_player.playing) unawaited(play());
    }
  }

  /// Look for the end of the other app's sound, and resume when it comes.
  ///
  /// Called off as soon as playback is no longer ours to resume: a Stop, a
  /// Play from the listener, or another station or cast started.

  void _waitForQuiet() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final stationId = _currentStation?.id;
    final castGuid = _currentCast?.guid;
    final started = DateTime.now();
    var quiet = 0;

    _focusPoll?.cancel();
    _focusPoll = Timer.periodic(focusPollEvery, (timer) async {
      if (_stopped ||
          _player.playing ||
          _currentStation?.id != stationId ||
          _currentCast?.guid != castGuid) {
        return timer.cancel();
      }

      try {
        quiet = await AndroidAudioManager().isMusicActive() ? 0 : quiet + 1;
      } catch (e) {
        debugPrint('[RadioAudioHandler] cannot tell if music plays: $e');

        return timer.cancel();
      }

      switch (focusWaitStep(
        waited: DateTime.now().difference(started),
        quietPolls: quiet,
      )) {
        case FocusWait.keepWaiting:
          break;
        case FocusWait.giveUp:
          timer.cancel();
        case FocusWait.resume:
          timer.cancel();
          unawaited(_resumeAfterOther());
      }
    });
  }

  /// Back on: the cast where it was, a station afresh at the live edge.

  Future<void> _resumeAfterOther() async {
    final station = _currentStation;
    if (station == null || _stopped || _player.playing) return;

    try {
      _currentCast != null
          ? await play()
          : await playStation(
              station,
              queue: _queueStations,
              parentId: _queueParentId,
            );
    } catch (e) {
      debugPrint('[RadioAudioHandler] could not resume ${station.name}: $e');
    }
  }

  /// Whether sound could go somewhere other than the phone itself: wired
  /// or Bluetooth headphones, earbuds, a car. Only Android can say;
  /// elsewhere, or if it cannot, the answer is yes, leaving a headset
  /// button as it always was.

  Future<bool> _headphonesConnected() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;

    try {
      final outputs = await AndroidAudioManager().getDevices(
        AndroidGetAudioDevicesFlags.outputs,
      );

      return hasOutputBeyondPhone(outputs.map((d) => d.type));
    } catch (e) {
      debugPrint('[RadioAudioHandler] cannot list audio outputs: $e');

      return true;
    }
  }

  /// Configure the session for speech (a cast) or music (a station), only
  /// when that changes. Best-effort: playback must not wait on it.

  Future<void> _useSessionFor({required bool speech}) async {
    if (_speechSession == speech) return;
    _speechSession = speech;

    try {
      final session = await AudioSession.instance;
      await session.configure(
        speech
            ? const AudioSessionConfiguration.speech()
            : const AudioSessionConfiguration.music(),
      );
    } catch (e) {
      debugPrint('[RadioAudioHandler] audio session configuration failed: $e');
    }
  }
}
