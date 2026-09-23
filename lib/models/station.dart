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

  /// True when the stream is HLS — an .m3u8 playlist of short segments
  /// rather than one continuous connection.
  ///
  /// WORTH AVOIDING ON THE DESKTOP. A live HLS playlist lists only a sliding
  /// window of segments, and the player is meant to re-read it as the window
  /// moves. libmpv, which is how RadioPod plays audio on GNU/Linux and
  /// Windows, reads the window once and then reports the stream as finished.
  /// ABC News Radio publishes six ten-second segments, so it dies after
  /// about fifty seconds, every time, whatever the network is doing.
  ///
  /// Many broadcasters publish the same station BOTH ways. ABC News Radio is
  /// on HLS at mediaserviceslive.akamaized.net and on plain Icecast at
  /// abc.streamguys1.com; the Icecast one plays for hours without a break.
  /// So Search marks HLS results, and the remedy is usually to pick the
  /// other entry for the same station rather than to work around the
  /// dropouts with [reconnectOnEnd].

  final bool isHls;

  /// What to do when this station's stream ends.
  ///
  /// Streams end for two reasons that look identical to the player, and the
  /// right response is opposite in each case, so the station says which.
  ///
  /// FALSE (the default) suits a programme that genuinely finishes. NPR's
  /// news bulletin closes the connection when the bulletin is over, and
  /// reconnecting simply replays the same news; the queue should move on.
  ///
  /// TRUE suits a continuous station whose connection drops mid-broadcast.
  /// ABC News Radio does this between bulletins and is still on air a moment
  /// later, so reconnecting picks the broadcast back up — often replaying a
  /// few seconds, which is Icecast handing a new listener its buffer.
  ///
  /// Nothing in the stream itself reveals which kind it is, so this is the
  /// listener's call, made once per station from the Stations screen.

  final bool reconnectOnEnd;

  /// The station's artwork, as a base64 PNG, when one has been stored.
  ///
  /// Takes precedence over [favicon]. That field is only a URL, and
  /// Radio-Browser's copy of it is dead for a good share of stations, so
  /// Properties offers to download it once and keep the bytes — after which
  /// the icon survives the link rotting, works offline, and can be replaced
  /// with a picture of the user's own choosing.
  ///
  /// Scaled to [stationIconWidth] before storing, because the whole station
  /// list is rewritten to the Pod on every edit and each icon is carried
  /// along every time.

  final String? icon;

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
    this.reconnectOnEnd = false,
    this.isHls = false,
    this.icon,
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
    if (isHls) 'HLS',
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
    if (reconnectOnEnd) 'reconnectOnEnd': true,
    if (isHls) 'isHls': true,
    if (icon != null) 'icon': icon,
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
    reconnectOnEnd: j['reconnectOnEnd'] as bool? ?? false,
    isHls: j['isHls'] as bool? ?? false,
    icon: j['icon'] as String?,
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
    bool? reconnectOnEnd,
    bool? isHls,
    Object? icon = _sentinel,
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
    reconnectOnEnd: reconnectOnEnd ?? this.reconnectOnEnd,
    isHls: isHls ?? this.isHls,
    icon: icon == _sentinel ? this.icon : icon as String?,
  );
}

const _sentinel = Object();
