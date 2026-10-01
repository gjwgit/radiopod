import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 20261001 gjw The Play Store upload key, following innerpod exactly.
//
// android/key.properties holds storePassword, keyPassword, keyAlias and
// storeFile, and android/app/keystore.jks is the keystore itself. NEITHER IS
// COMMITTED — android/.gitignore already excludes key.properties, **/*.jks
// and **/*.keystore.
//
// Signing is done on this machine FOR NOW, as innerpod does it: `make
// appbundle` builds and signs locally and the Makefile rsyncs the result, so
// there are no keystore secrets in GitHub yet.
//
// Moving it to CI needs nothing here. The job writes key.properties from
// secrets before it builds — base64 the .jks into one secret, the four
// property values into others — and this file reads it exactly as it does on
// a developer machine. Follow the pattern package-ios-ipa already uses for
// IOS_CERTIFICATE and IOS_PROVISION_PROFILE.

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Whether this machine can sign a release at all. A CI runner cannot, by
// design, and must still be able to build DEBUG for the screenshots job.

val hasUploadKey = keystorePropertiesFile.exists()

android {
    namespace = "com.togaware.radiopod"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.togaware.radiopod"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // oidcRedirectScheme is required by oidc_android, which declares no
        // default for it, so the manifest merger fails without it. The scheme
        // must match the custom redirect URI registered in app.dart and
        // client-profile.jsonld: com.togaware.radiopod://redirect
        manifestPlaceholders.putAll(
            mapOf(
                "appAuthRedirectScheme" to "com.togaware.radiopod",
                "oidcRedirectScheme" to "com.togaware.radiopod",
            )
        )
    }

    // 20261001 gjw Created ONLY when key.properties is there.
    //
    // Gradle evaluates this block during CONFIGURATION, for every task — so
    // casting a missing property here broke `assembleDebug` too, and with it
    // the Android screenshots job, which has no keystore and needs none. The
    // guard below puts the loud failure back where it belongs: on a release
    // build, and nowhere else.

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 20261001 gjw Was the DEBUG key, which is the Flutter template's
            // placeholder. That is how installers/radiopod.aab came to be
            // signed CN=Android Debug — a build Play rejects outright, and
            // one that cannot be upgraded to a properly signed version later
            // because the signature would not match.
            //
            // NOT falling back to the debug key when key.properties is
            // absent, deliberately. A missing keystore fails the build
            // loudly rather than quietly producing an unshippable artefact
            // that looks fine until it is uploaded. findByName gives null
            // there, and the task-graph guard below turns that into an
            // error the moment a release build is actually asked for.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// 20261001 gjw Refuse a RELEASE build with no upload key, and only then.
//
// Checked against the task graph rather than at configuration, so `flutter
// build apk --debug` and the integration_test run in .github/workflows/
// screenshots.yaml are untouched on a machine that has no keystore — which
// is every CI runner, since the key is deliberately not a GitHub secret.

if (!hasUploadKey) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.name.contains("Release") }) {
            throw GradleException(
                "android/key.properties is missing, so a release build " +
                    "cannot be signed with the upload key. See " +
                    "ignore/ANDROID.md — it is four lines pointing at " +
                    "~/upload-keystore.jks.",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
