package com.togaware.radiopod

import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider

/// Serves the user's chosen station icons to Android Auto.
///
/// 20261006 gjw WHY THIS EXISTS. A station's own logo is an https URL, and
/// the car fetches it itself. A picture the user chose is a local file, and
/// Android Auto's process cannot read our app-private storage, so a `file://`
/// artUri shows as nothing on any surface the car renders from the URI — the
/// browse list, and the narrow now-playing card beside the map. The wide
/// now-playing view works, because that one draws the bitmap audio_service
/// loads in OUR process (AudioService.java:811). Same metadata, two surfaces,
/// only one of them reading the URI — which is exactly the symptom.
///
/// A `content://` URI is readable across processes, and audio_service already
/// passes one through to the session untouched while still loading the bitmap
/// itself via openFileDescriptor (AudioService.java:794), so the wide view
/// keeps working unchanged.
class StationIconProvider : FileProvider() {

    /// Grant Android Auto read access as soon as the process exists.
    ///
    /// onCreate is the right place and an Activity is NOT: the car starts the
    /// media service on its own, with no activity and often before the user
    /// has unlocked anything (CLAUDE.md §4). A ContentProvider is created on
    /// EVERY process start, including that headless one, and before
    /// Application.onCreate.
    ///
    /// An explicit grant is needed because audio_service never tells us who
    /// is browsing — its onGetRoot listener is commented out
    /// (AudioService.java:825) — so there is no client package to grant to
    /// on demand. Granting by PREFIX covers every icon file under the one
    /// directory, so a station added later needs no further grant.
    override fun onCreate(): Boolean {
        val created = super.onCreate()

        val ctx = context
        if (ctx != null) {
            val root = Uri.parse("content://${ctx.packageName}$AUTHORITY_SUFFIX/$ICONS")
            val mode = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION

            for (pkg in AUTO_HOSTS) {
                try {
                    ctx.grantUriPermission(pkg, root, mode)
                } catch (e: Exception) {
                    // A host that is not installed is the normal case, not a
                    // fault: almost nobody has the desktop head unit. An icon
                    // that cannot be granted costs a picture in the car and
                    // must never stop the provider being created, because the
                    // media service is starting behind it.
                    Log.d(TAG, "no grant for $pkg: $e")
                }
            }
        }

        return created
    }

    companion object {
        private const val TAG = "StationIconProvider"

        /// Matches android:authorities in the manifest, which is built from
        /// ${applicationId}, and stationIconAuthority on the Dart side.
        private const val AUTHORITY_SUFFIX = ".stationicons"

        /// The <files-path name> in res/xml/station_icon_paths.xml.
        private const val ICONS = "station_icons"

        /// Who may read the icons. Deliberately a short, named list rather
        /// than exporting the provider: only the Android Auto host and the
        /// desktop head unit used to test it without a car.
        private val AUTO_HOSTS = listOf(
            "com.google.android.projection.gearhead",
            "com.google.android.autosimulator",
        )
    }
}
