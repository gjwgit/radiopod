#!/bin/bash

# Build the Debian package for RadioPod.
#
# From the gjwgit/fluttertmpl Copier template, with the package details
# from .copier-answers.yml. Local edits are kept by `copier update`.
#
# 20261030 gjw One script for the local `make deb` and the installers
# workflow. Locally it builds the Flutter Linux release first. With
# --bundle it packages the bundle already in build/linux/x64/release, as
# the workflow's build-linux job leaves it, so every Linux installer
# carries the same binary.
#
# Run from the installers folder. Leaves radiopod_<version>_amd64.deb
# here.

set -e

APP=radiopod

VER=$(grep '^version:' ../pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)

if [ "$1" != "--bundle" ]; then

  # 20261018 gjw Pass dart_defines.json, as support/flutter.mk and CI do,
  # or the build.secrets are not compiled in:
  #
  #   PODCAST_INDEX_KEY PODCAST_INDEX_SECRET
  #
  # Obfuscated like the other release builds, so the scrambled values
  # are harder to dig out of the binary.

  DEFINES=""
  if [ -f ../dart_defines.json ]; then
    DEFINES="--dart-define-from-file=dart_defines.json --obfuscate --split-debug-info=build/symbols"
  else
    echo "Warning: no dart_defines.json, so the build.secrets are missing."
    echo "Run: dart run support/scramble_defines.dart"
  fi
  (cd ..; flutter build linux --release ${DEFINES})
fi

ROOT=${APP}_${VER}_amd64

# Create debian package structure.

mkdir -p ${ROOT}/DEBIAN
mkdir -p ${ROOT}/usr/bin
mkdir -p ${ROOT}/usr/lib/${APP}
mkdir -p ${ROOT}/usr/share/applications
mkdir -p ${ROOT}/usr/share/icons/hicolor/512x512/apps

# Create control file. The heredocs are quoted so the description is
# written as it is.

cat > ${ROOT}/DEBIAN/control << 'EOL'
Package: radiopod
Section: sound
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libblkid1, liblzma5, libmpv2
Maintainer: Graham Williams <graham.williams@togaware.com>
Description: Privacy-first internet radio and podcast player
 RadioPod plays internet radio and podcasts. Find stations in the
 community-run Radio-Browser database and podcasts in Podcast Index,
 group them into playlists, and listen — at your desk, on your phone,
 or in the car through Android Auto.
 .
 A podcast sits in your list beside the stations. Tap it to resume the
 episode you were part way through, or else start the newest. Each
 episode remembers where you stopped, so you can pick it up on another
 device, and you can skip back and forward or mark it played.
 .
 Your stations, podcasts, playlists and listening progress are stored
 encrypted in your personal online data store (Pod) within a Data
 Vault hosted by your Solid Server of choice, so nobody — not even the
 server administrator — can see what you listen to. Without a login
 the library is kept on this device instead and nothing is sent
 anywhere.
 .
 Playlists import and export as M3U and PLS, the open formats every
 other radio player reads. Podcasts import and export as OPML, so you
 can bring your subscriptions from another podcast app.
EOL
echo "Version: ${VER}" >> ${ROOT}/DEBIAN/control

# Create desktop entry.

cat > ${ROOT}/usr/share/applications/com.togaware.${APP}.desktop << 'EOL'
[Desktop Entry]
Name=RadioPod
Comment=Simple, Private, Secure Internet Radio and Podcasts
Exec=/usr/bin/radiopod
Icon=radiopod
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Player;Network;
Keywords=radio;internet radio;streaming;shoutcast;icecast;podcast;podcasts;solid;pod;
EOL

# Copy the built flutter application.

cp -r ../build/linux/x64/release/bundle/* ${ROOT}/usr/lib/${APP}/

# Ensure /usr/bin/${APP} points to the actual executable.

(cd ${ROOT}/usr/bin; ln -s ../lib/${APP}/${APP} ${APP})

# The app icon.

cp ../assets/images/app_icon.png ${ROOT}/usr/share/icons/hicolor/512x512/apps/${APP}.png

# Set correct permissions.

chmod 755 ${ROOT}
chmod -R 755 ${ROOT}/DEBIAN
find ${ROOT}/usr -type d -exec chmod 755 {} \;
find ${ROOT}/usr -type f -exec chmod 644 {} \;
chmod 755 ${ROOT}/usr/lib/${APP}/${APP}

# Build the debian package.

dpkg-deb --build --root-owner-group ${ROOT}

# Cleanup.

rm -rf ${ROOT}
