/// Cast — one episode of a podcast, with the listener's progress through it.
///
// Time-stamp: <Friday 2026-10-16 06:00:00 +1100 Graham Williams>
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

/// One episode of a podcast.
///
/// 20261016 gjw Two kinds of field live together here. The feed supplies
/// [guid], [title], [published], [duration], [audioUrl] and [description],
/// and a refresh may change any of them. The listener supplies [disabled],
/// [played] and [position], which a refresh must never touch; see
/// `mergeFeed`. [updatedAt] stamps the listener's last change, so a car
/// session recorded on the device and a session on another device written to
/// the Pod can be reconciled cast by cast, the newer winning.

class Cast {
  /// The feed's `<guid>`, or the audio URL when the feed gives none. Stable
  /// across refreshes, which is the whole of its job.

  final String guid;
  final String title;
  final DateTime published;

  /// From `itunes:duration`, when the feed states it. Many do not, and the
  /// player learns the real length once the audio opens.

  final Duration? duration;

  /// The enclosure: the audio itself.

  final String audioUrl;

  /// The show notes as plain text, trimmed. Kept short because the whole
  /// cast list is rewritten to the Pod on every change.

  final String description;

  /// Chosen by the listener: never play this one.

  final bool disabled;

  /// Played to the end. Kept in the list, greyed, rather than removed.

  final bool played;

  /// How far in the listener got, to resume from. Zero when not started or
  /// once played.

  final Duration position;

  /// When the listener's state last changed, or null if it never has.

  final DateTime? updatedAt;

  const Cast({
    required this.guid,
    required this.title,
    required this.published,
    required this.audioUrl,
    this.duration,
    this.description = '',
    this.disabled = false,
    this.played = false,
    this.position = Duration.zero,
    this.updatedAt,
  });

  /// Neither disabled nor played: still waiting to be heard.

  bool get available => !disabled && !played;

  /// Time still to hear, when the length is known.

  Duration? get remaining =>
      duration == null || duration! <= position ? null : duration! - position;

  Map<String, dynamic> toJson() => {
    'guid': guid,
    'title': title,
    'published': published.toUtc().toIso8601String(),
    'audioUrl': audioUrl,
    if (duration != null) 'duration': duration!.inSeconds,
    if (description.isNotEmpty) 'description': description,
    if (disabled) 'disabled': true,
    if (played) 'played': true,
    if (position > Duration.zero) 'position': position.inSeconds,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  factory Cast.fromJson(Map<String, dynamic> j) => Cast(
    guid: j['guid'] as String,
    title: j['title'] as String? ?? '',
    published:
        DateTime.tryParse(j['published'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    audioUrl: j['audioUrl'] as String,
    duration: _seconds(j['duration']),
    description: j['description'] as String? ?? '',
    disabled: j['disabled'] as bool? ?? false,
    played: j['played'] as bool? ?? false,
    position: _seconds(j['position']) ?? Duration.zero,
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
  );

  /// The feed's side of [fresh] with this cast's listener state kept.

  Cast withFeedOf(Cast fresh) => Cast(
    guid: guid,
    title: fresh.title,
    published: fresh.published,
    audioUrl: fresh.audioUrl,
    duration: fresh.duration ?? duration,
    description: fresh.description,
    disabled: disabled,
    played: played,
    position: position,
    updatedAt: updatedAt,
  );

  /// A change of listener state, stamped [at] (now by default).

  Cast withState({
    bool? disabled,
    bool? played,
    Duration? position,
    DateTime? at,
  }) => Cast(
    guid: guid,
    title: title,
    published: published,
    audioUrl: audioUrl,
    duration: duration,
    description: description,
    disabled: disabled ?? this.disabled,
    played: played ?? this.played,
    position: position ?? this.position,
    updatedAt: at ?? DateTime.now().toUtc(),
  );

  /// With the length the player found, when the feed did not say.

  Cast withDuration(Duration d) => Cast(
    guid: guid,
    title: title,
    published: published,
    audioUrl: audioUrl,
    duration: d,
    description: description,
    disabled: disabled,
    played: played,
    position: position,
    updatedAt: updatedAt,
  );

  static Duration? _seconds(Object? v) =>
      v is num ? Duration(seconds: v.toInt()) : null;
}
