/// Station — a single internet radio station.
///
// Time-stamp: <Saturday 2026-09-20 06:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

/// One radio station in the user's library.
///
/// A station is identified locally by [id] so that two stations imported from
/// different playlists never collide. [stationUuid] is the Radio-Browser
/// identifier and is present only for stations found through Search — it is
/// kept so a later lookup can refresh a dead stream URL, and is absent for
/// stations imported from an M3U or PLS file.

class Station {
  final String id;
  final String name;
  final String url;
  final String? homepage;
  final String? favicon;
  final String? country;
  final String? language;
  final String? codec;
  final int? bitrate;
  final List<String> tags;
  final String? stationUuid;

  const Station({
    required this.id,
    required this.name,
    required this.url,
    this.homepage,
    this.favicon,
    this.country,
    this.language,
    this.codec,
    this.bitrate,
    this.tags = const [],
    this.stationUuid,
  });

  // ── Derived properties ────────────────────────────────────────────────────

  /// A one-line summary for the second line of a list tile.
  ///
  /// Only the parts we actually know are joined, so a hand-imported station
  /// with nothing but a name and URL shows an empty subtitle rather than a
  /// row of separators.

  String get subtitle => [
    if (country != null && country!.isNotEmpty) country,
    if (language != null && language!.isNotEmpty) language,
    if (codec != null && codec!.isNotEmpty) codec,
    if (bitrate != null && bitrate! > 0) '$bitrate kbps',
  ].join(' · ');

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    if (homepage != null) 'homepage': homepage,
    if (favicon != null) 'favicon': favicon,
    if (country != null) 'country': country,
    if (language != null) 'language': language,
    if (codec != null) 'codec': codec,
    if (bitrate != null) 'bitrate': bitrate,
    if (tags.isNotEmpty) 'tags': tags,
    if (stationUuid != null) 'stationUuid': stationUuid,
  };

  factory Station.fromJson(Map<String, dynamic> j) => Station(
    id: j['id'] as String,
    name: j['name'] as String,
    url: j['url'] as String,
    homepage: j['homepage'] as String?,
    favicon: j['favicon'] as String?,
    country: j['country'] as String?,
    language: j['language'] as String?,
    codec: j['codec'] as String?,
    bitrate: (j['bitrate'] as num?)?.toInt(),
    tags: (j['tags'] as List?)?.cast<String>() ?? const [],
    stationUuid: j['stationUuid'] as String?,
  );

  Station copyWith({
    String? id,
    String? name,
    String? url,
    Object? homepage = _sentinel,
    Object? favicon = _sentinel,
    Object? country = _sentinel,
    Object? language = _sentinel,
    Object? codec = _sentinel,
    Object? bitrate = _sentinel,
    List<String>? tags,
    Object? stationUuid = _sentinel,
  }) => Station(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    homepage: homepage == _sentinel ? this.homepage : homepage as String?,
    favicon: favicon == _sentinel ? this.favicon : favicon as String?,
    country: country == _sentinel ? this.country : country as String?,
    language: language == _sentinel ? this.language : language as String?,
    codec: codec == _sentinel ? this.codec : codec as String?,
    bitrate: bitrate == _sentinel ? this.bitrate : bitrate as int?,
    tags: tags ?? this.tags,
    stationUuid: stationUuid == _sentinel
        ? this.stationUuid
        : stationUuid as String?,
  );
}

const _sentinel = Object();
