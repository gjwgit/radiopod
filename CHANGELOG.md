# RadioPod Change Log

Noted below are the high level changes for the app. Each update
includes a short user-oriented description, version number, date, and
developer.

You can run the app in your
[**browser**](https://radiopod.solidcommunity.au) or else download and
install locally the latest version from the [Solid Community
AU](https://solidcommunity.au) or directly:

+ **Android** as
[apk](https://solidcommunity.au/installers/radiopod.apk) or
[aab](https://solidcommunity.au/installers/radiopod.aab);
+ **GNU/Linux** as
[deb](https://solidcommunity.au/installers/radiopod_amd64.deb) or
[snap](https://solidcommunity.au/installers/radiopod_amd64.snap) or
[zip](https://solidcommunity.au/installers/radiopod-linux.zip);
+ **macOS** as
[dmg](https://solidcommunity.au/installers/radiopod-macos.dmg) or
[zip](https://solidcommunity.au/installers/radiopod-macos.zip);
+ **Windows** as
[exe](https://solidcommunity.au/installers/radiopod-windows-inno.exe)
or [zip](https://solidcommunity.au/installers/radiopod-windows.zip).

Contributions are welcome. Visit
[github](https://github.com/gjwgit/radiopod) to submit an issue or,
even better, fork the repository yourself, update the code, and submit
a Pull Request.

We make this project available for free so if you appreciate the app
then please show some ❤️ and tap on the star at
[GitHub](https://github.com/gjwgit/radiopod) to support our work.

This app is authored by [Graham
Williams](https://togaware.com/Graham.Williams.html).

## 1.1 Feature Tuning

+ Add a station manually from the app bar [1.1.14 20260925 gjw]
+ Station properties now show the stream details [1.1.13 20260925 gjw]
+ Icon is the dial and waves alone, on transparency [1.1.12 20260924 gjw]
+ Test snap install [1.1.11 20260924 gjw]
+ Update to solidui to allow CONTINUE without secrets [1.1.10 20260924 gjw]
+ Web: switching station stops the one already playing [1.1.9 20260924 gjw]
+ Web: Stop really stops, and switching station works [1.1.8 20260924 gjw]
+ Web: station logos show instead of falling back to a glyph [1.1.7 20260924 gjw]
+ Snap: allow the keyring access a Pod login needs [1.1.6 20260924 gjw]
+ Snap: play audio again, by finding libmpv's blas and lapack [1.1.5 20260924 gjw]
+ A stopped station shows its icon again, not a play button [1.1.4 20260923 gjw]
+ Station icons no longer flicker while a stream plays [1.1.3 20260923 gjw]
+ Station Properties: rename, set an icon, reconnect option [1.1.2 20260923 gjw]
+ Stations saved from Search go to the top of the list [1.1.1 20260923 gjw]
+ Playing row is now player, replacing the overlapping card [1.1.0 20260923 gjw]

## 1.0 Functional App

+ Stop no longer makes the station stop itself again [1.0.17 20260923 gjw]
+ Linux: Stop responds at once and Play restarts the stream [1.0.16 20260923 gjw]
+ Adaptive Android icon so it shows properly in Android Auto [1.0.15 20260923 gjw]
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
+ Background playback with notification and headset controls [0.0.6 20260921 gjw]
+ Android Auto browse tree of playlists and all stations [0.0.5 20260921 gjw]
+ Import and export M3U, M3U8 and PLS playlist files [0.0.4 20260921 gjw]
+ Search the Radio-Browser database by station name or genre [0.0.3 20260921 gjw]
+ Station library and playlists stored encrypted on the Pod [0.0.2 20260921 gjw]
+ Initial app skeleton from the todopod solidui template [0.0.1 20260920 gjw]
