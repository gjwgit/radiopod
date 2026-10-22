# RadioPod Change Log

Noted below are the high level changes for the app. Each update
includes a short user-oriented description, version number, date, and
developer.

Contributions are welcome. Visit
[github](https://github.com/gjwgit/radiopod) to submit an issue or,
even better, fork the repository yourself, update the code, and submit
a Pull Request.

We make this project available for free so if you appreciate the app
then please show some ❤️ and tap on the star at
[GitHub](https://github.com/gjwgit/radiopod) to support our work.

This app is authored by [Graham
Williams](https://togaware.com/Graham.Williams.html).

## 2.1 Tidy up import/export and fine tune

+ No error popup when tapping another station while connecting [2.1.6 20261022 gjw]
+ Login status bar on narrower windows, solidui 1.5.12 [2.1.5 20261022 gjw]
+ Sleep timer resets on Stop, not on switching station [2.1.4 20261022 gjw]
+ Update to solidui 1.5.11 [2.1.3 20261021 gjw]
+ Write casts to Pod once at startup, not once per podcast [2.1.2 20261021 gjw]
+ Exports named in lowercase with a date, radiopod_20261021 [2.1.1 20261021 gjw]
+ Import/Export page by direction, OPML beside M3U/PLS [2.1.0 20261021 gjw]

## 2.0 Podcasts

+ Rows begin Radio or Podcast; podcasts say 2 to play [2.0.19 20261019 gjw]
+ Say "Nothing left to play", not a stream error [2.0.18 20261018 gjw]
+ Podcast with no episodes left moves to next station [2.0.17 20261018 gjw]
+ Episode length from the audio, not the feed [2.0.16 20261018 gjw]
+ Fix Android start-up hang from shared_preferences 2.5 [2.0.15 20261018 gjw]
+ Search info button shows details, podcast description [2.0.14 20261018 gjw]
+ Logos fetched once and kept, not on each play [2.0.13 20261018 gjw]
+ make upload_android sends the bundle to Play testing [2.0.12 20261018 gjw]
+ Tap a podcast to resume a part-heard episode [2.0.11 20261018 gjw]
+ Starting an episode picks up progress from other devices [2.0.10 20261017 gjw]
+ Episode progress reaches Pod while playing, read on return [2.0.9 20261017 gjw]
+ Podcast properties update from the feed, no reconnect switch [2.0.8 20261017 gjw]
+ Toolbar refreshes podcasts, say episodes not casts [2.0.7 20261017 gjw]
+ Split the provider and audio handler to keep under 300 lines [2.0.6 20261017 gjw]
+ Refresh says when not logged in rather than up to date [2.0.5 20261016 gjw]
+ Import and export podcasts as OPML [2.0.4 20261016 gjw]
+ Show what is playing in the empty Stations filter box [2.0.3 20261016 gjw]
+ Resume a cast 5 seconds back from where it was left [2.0.2 20261016 gjw]
+ Skip all, or unskip all, of a podcast's casts [2.0.1 20261016 gjw]
+ Podcasts: Podcast Index, tap to play, resume, skip, seek [2.0.0 20261016 gjw]

## 1.5 Starter stations

+ Keep stations saved before login, offer to copy them to Pod [1.5.13 20261015 gjw]
+ Search by location, @sydney news to combine with keywords [1.5.12 20261015 gjw]
+ Show saved security key in footer early, solidui 1.5.7 [1.5.11 20261014 gjw]
+ Fill in hand-added station details from Radio-Browser [1.5.10 20261014 gjw]
+ Explain a station that refuses your country [1.5.9 20261014 gjw]
+ Sleep timer fades out over its last 30 seconds [1.5.8 20261013 gjw]
+ Keep the security key after a Session Expired login [1.5.7 20261013 gjw]
+ Stop and Play button beside Filter and Search [1.5.6 20261013 gjw]
+ Optionally start the sleep timer on playing [1.5.5 20261013 gjw]
+ Bump solidui 1.5.4 solidpod 1.1.1 [1.5.4 20261011 gjw]
+ Update to solidui 1.5.3 Login and Register share a row [1.5.3 20261009 gjw]
+ Station actions become buttons on a wide screen [1.5.2 20261008 gjw]
+ Starter stations now include lounge and classical [1.5.1 20261008 gjw]
+ An empty library starts with three popular stations [1.5.0 20261008 gjw]

## 1.4 Sleep timer

+ Update solidui 1.4.5 no login flash when skipped [1.4.2 20261007 gjw]
+ Fix the double spinner when starting up [1.4.1 20261007 gjw]
+ Sleep timer stops playback after a set time [1.4.0 20261006 gjw]

## 1.3 Skip login is enabled by default and Android Auto is working

+ Fix the car dropping back to the list on Next [1.3.9 20261006 gjw]
+ Fix the car display stalling on a song change [1.3.8 20261006 gjw]
+ Drag to reorder the playlists themselves [1.3.7 20261005 gjw]
+ Drag to reorder the stations within a playlist [1.3.6 20261005 gjw]
+ Keep station logos in the car's browse list [1.3.5 20261005 gjw]
+ Chosen station icon shows on the car's Now Playing [1.3.4 20261005 gjw]
+ Update solidui 1.4.4 wavy menu lines if logged in [1.3.3 20261005 gjw]
+ Update solidui 1.4.3 indicates if logged in [1.3.2 20261004 gjw]
+ An expired Pod session no longer asks for a key [1.3.1 20261004 gjw]
+ Update to solidui 1.4.0 with skip Login [1.3.0 20261002 gjw]

## 1.2 Add support for Apple CarPlay

+ Add initial support for Apple CarPlay [1.2.0 20261002 tonypioneer]

## 1.1 Feature Tuning

+ Retain logo on playing station [1.1.23 20261002 tonypioneer]
+ Cancelling the security key no longer loops [1.1.22 20261002 gjw]
+ Fix the iOS login, broken by a stripped symbol [1.1.21 20260929 gjw]
+ Diagnostics cover a login failing early [1.1.20 20260929 gjw]
+ Settings reports why a login did not complete [1.1.19 20260929 gjw]
+ iOS App Store build tested and working [1.1.18 20260928 gjw]
+ iOS App Store build, and a build number that increments [1.1.17 20260928 gjw]
+ Update a saved station from Radio-Browser [1.1.16 20260925 gjw]
+ Station addresses in Properties open on a tap [1.1.15 20260925 gjw]
+ Add a station manually from the app bar [1.1.14 20260925 gjw]
+ Station properties now show the stream details [1.1.13 20260925 gjw]
+ Icon is the dial and waves alone, on transparency [1.1.12 20260924 gjw]
+ Test snap install [1.1.11 20260924 gjw]
+ Update to solidui to allow CONTINUE without secrets [1.1.10 20260924 gjw]
+ Web: switching station stops the one already playing [1.1.9 20260924 gjw]
+ Web: Stop really stops, and switching station works [1.1.8 20260924 gjw]
+ Web: station logos show instead of falling back to a
  glyph [1.1.7 20260924 gjw]
+ Snap: allow the keyring access a Pod login needs [1.1.6 20260924 gjw]
+ Snap: play audio again, by finding libmpv's blas and
  lapack [1.1.5 20260924 gjw]
+ A stopped station shows its icon again, not a play button [1.1.4 20260923 gjw]
+ Station icons no longer flicker while a stream plays [1.1.3 20260923 gjw]
+ Station Properties: rename, set an icon, reconnect option [1.1.2 20260923 gjw]
+ Stations saved from Search go to the top of the list [1.1.1 20260923 gjw]
+ Playing row is now player, replacing the overlapping card [1.1.0 20260923 gjw]

## 1.0 Functional App

+ Stop no longer makes the station stop itself again [1.0.17 20260923 gjw]
+ Linux: Stop responds at once and Play restarts the
  stream [1.0.16 20260923 gjw]
+ Adaptive Android icon so it shows properly in Android
  Auto [1.0.15 20260923 gjw]
+ Android Auto opens on a scrollable station list [1.0.14 20260923 gjw]
+ Rounded icon with transparency for Linux and macOS [1.0.13 20260923 gjw]
+ New app artwork: a tuner dial receiving a signal [1.0.12 20260923 gjw]
+ macOS: ship app icon instead of default Flutter logo [1.0.11 20260923 gjw]
+ macOS: allow the plain http streams most stations use [1.0.10 20260923 gjw]
+ macOS: stop asking the keychain before the login screen [1.0.9 20260922 gjw]
+ Avoid Impeller rendering for now [1.0.8 20260922 gjw]
+ macOS: unsandbox the Release entitlements WIP [1.0.7 20260922 gjw]
+ Mark HLS streams and show one Search result per stream [1.0.6 20260922 gjw]
+ Move to the next station when a stream ends, or reconnect [1.0.5 20260922 gjw]
+ Drag stations into your own order on the Stations screen [1.0.4 20260922 gjw]
+ Add support for macOS installer builds [1.0.3 20260922 gjw]
+ Generated all icons [1.0.2 20260921 gjw]
+ Add snapcraft config to build a snap [1.0.1 20260921 gjw]
+ Save data locally if not logged in [1.0.0 20260921 gjw]

## 0.0 Initial App

+ Display title of playing track [0.0.9 20260921 gjw]
+ Privacy page naming exactly what leaves the device [0.0.8 20260921 gjw]
+ libmpv playback backend for GNU/Linux and Windows [0.0.7 20260921 gjw]
+ Background playback with notification and headset
  controls [0.0.6 20260921 gjw]
+ Android Auto browse tree of playlists and all stations [0.0.5 20260921 gjw]
+ Import and export M3U, M3U8 and PLS playlist files [0.0.4 20260921 gjw]
+ Search the Radio-Browser database by station name or
  genre [0.0.3 20260921 gjw]
+ Station library and playlists stored encrypted on the Pod [0.0.2 20260921 gjw]
+ Initial app skeleton from the todopod solidui template [0.0.1 20260920 gjw]
