/// When to come back after another app took the sound outright.
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

library;

import 'package:audio_session/audio_session.dart';

/// How often to look whether the other app's sound has finished.

const focusPollEvery = Duration(seconds: 2);

/// How many looks in a row must find silence: a gap between two tracks or
/// two voice messages is not the other app finishing.

const focusQuietPolls = 2;

/// How long to keep looking. Past this the listener has moved on to the
/// other app, and the radio coming back on by itself would be a surprise.
///
/// 20261023 gjw Thirty seconds, as AntennaPod waits for the sound back
/// after a short interruption (LocalPSMP.java): enough for a voice message
/// or a clip, never long enough to come back on over an hour of music.

const focusWaitLimit = Duration(seconds: 30);

/// What to do on one look.

enum FocusWait { keepWaiting, resume, giveUp }

/// The decision for one look, [waited] after the sound was taken, with
/// [quietPolls] looks in a row having found no other sound.

FocusWait focusWaitStep({required Duration waited, required int quietPolls}) {
  if (quietPolls >= focusQuietPolls) return FocusWait.resume;
  if (waited >= focusWaitLimit) return FocusWait.giveUp;

  return FocusWait.keepWaiting;
}

/// The phone's own outputs. A headset button may start playback only while
/// some OTHER output is connected (earbuds, headphones, a car), so earbuds
/// put away in their case cannot set the phone's speaker going.
///
/// The phone's outputs are listed rather than the headphones, because
/// audio_session predates LE Audio and reports such earbuds as unknown.

const phoneOutputs = {
  AndroidAudioDeviceType.builtInEarpiece,
  AndroidAudioDeviceType.builtInSpeaker,
  AndroidAudioDeviceType.builtInSpeakerSafe,
  AndroidAudioDeviceType.builtInMic,
  AndroidAudioDeviceType.telephony,
  AndroidAudioDeviceType.remoteSubmix,
  AndroidAudioDeviceType.fm,
  AndroidAudioDeviceType.fmTuner,
  AndroidAudioDeviceType.tvTuner,
};

/// Whether any of [outputs] takes sound away from the phone itself.

bool hasOutputBeyondPhone(Iterable<AndroidAudioDeviceType> outputs) =>
    outputs.any((t) => !phoneOutputs.contains(t));
