#!/bin/bash

APP=$(pwd | rev | cut -d'/' -f2 | rev)

VER=$(egrep '^version:' ../pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)

# Build the release.
#
# 20261018 gjw Pass dart_defines.json, as support/flutter.mk and CI do.
# Without it the Podcast Index pair is not compiled in and podcast search
# says it is unavailable. Obfuscated like the other release builds, so the
# scrambled pair is harder to dig out of the binary.

DEFINES=""
if [ -f ../dart_defines.json ]; then
  DEFINES="--dart-define-from-file=dart_defines.json"
else
  echo "Warning: no dart_defines.json, so podcast search will be unavailable."
  echo "Run: dart run support/scramble_defines.dart"
fi

(cd ..; flutter build linux --release ${DEFINES} \
  --obfuscate --split-debug-info=build/symbols)

# Create debian package structure.

mkdir -p ${APP}_${VER}_amd64/DEBIAN
mkdir -p ${APP}_${VER}_amd64/usr/bin
mkdir -p ${APP}_${VER}_amd64/usr/lib/${APP}
mkdir -p ${APP}_${VER}_amd64/usr/share/applications
mkdir -p ${APP}_${VER}_amd64/usr/share/icons/hicolor/512x512/apps

# Create control file.

cat > ${APP}_${VER}_amd64/DEBIAN/control << EOL
Package: ${APP}
Version: ${VER}
Section: sound
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libblkid1, liblzma5, libmpv2
Maintainer: Graham Williams <graham.williams@togaware.com>
Description: Privacy-first internet radio and podcast player
 With ${APP} you can find internet radio stations in the community-run
 Radio-Browser database and podcasts in Podcast Index, group them into
 playlists, and listen. Your library and listening progress are stored
 encrypted in your Pod, so nobody can see what you listen to. Playlists
 import and export as M3U and PLS, podcasts as OPML.
EOL

# Create desktop entry.

cat > ${APP}_${VER}_amd64/usr/share/applications/com.togaware.${APP}.desktop << EOL
[Desktop Entry]
Name=RadioPod
Comment=Simple, Private, Secure Internet Radio and Podcasts with your Solid Pod
Exec=/usr/bin/${APP}
Icon=${APP}
Terminal=false
Type=Application
Categories=Utility;
EOL

# Copy the built flutter application.

cp -r ../build/linux/x64/release/bundle/* ${APP}_${VER}_amd64/usr/lib/${APP}/

# Ensure /usr/bin/${APP} points to the actual executable.

(cd ${APP}_${VER}_amd64/usr/bin; ln -s ../lib/${APP}/${APP} ${APP})

# Copy the app icon which is assumed to be named ${APP}.png in the
# installers folder.

cp ../assets/images/app_icon.png ${APP}_${VER}_amd64/usr/share/icons/hicolor/512x512/apps/${APP}.png

# Set correct permissions.

chmod -R 755 ${APP}_${VER}_amd64/DEBIAN
find ${APP}_${VER}_amd64/usr -type d -exec chmod 755 {} \;
find ${APP}_${VER}_amd64/usr -type f -exec chmod 644 {} \;
chmod 755 ${APP}_${VER}_amd64/usr/lib/${APP}/${APP}

# Build the debian package.

dpkg-deb --build --root-owner-group ${APP}_${VER}_amd64

# Cleanup.

rm -rf ${APP}_${VER}_amd64
