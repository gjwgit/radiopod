#!/bin/bash

APP=$(pwd | rev | cut -d'/' -f2 | rev)

VER=$(egrep '^version:' ../pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)

# Build the release.

(cd ..; flutter build linux --release)

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
Description: Privacy preserving internet radio player
 With ${APP} you can find internet radio stations in the community-run
 Radio-Browser database, group them into playlists, and listen. Your
 station library is stored encrypted in your Pod, so nobody can see
 what you listen to. Playlists import and export as M3U and PLS.
EOL

# Create desktop entry.

cat > ${APP}_${VER}_amd64/usr/share/applications/com.togaware.${APP}.desktop << EOL
[Desktop Entry]
Name=RadioPod
Comment=Collect your contacts in Pods
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

# Copy the app icon. A SHAPED variant may be used here: GNOME, KDE
# and the other desktops draw the icon exactly as given, with no masking, so
# app_icon.png carries the mark alone — the dial and its signal arcs, with
# everything outside them transparent — so it does not appear as a
# hard-edged square next to every other application
# and its transparent surround. Not all apps are supporting this yet. See radiopod.

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
