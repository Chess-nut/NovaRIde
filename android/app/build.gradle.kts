import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// `flutter run --dart-define=NAME=value` (or --dart-define-from-file) reaches
// Gradle as one `dart-defines` property: the entries base64-encoded and
// comma-joined. Decoded here so the same flag that feeds Dart also feeds the
// manifest, and a key never has to live in a file under android/.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotBlank() }
        ?.map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        ?.mapNotNull { entry ->
            val separator = entry.indexOf('=')
            if (separator > 0) entry.substring(0, separator) to entry.substring(separator + 1) else null
        }
        ?.toMap()
        ?: emptyMap()

// Maps SDK for Android key, restricted in Google Cloud to this package name
// and the signing certificate's SHA-1. Empty when not supplied: the build
// still succeeds and the map renders blank, which is the right failure for
// a checkout without credentials.
val googleMapsApiKeyAndroid: String = dartDefines["GOOGLE_MAPS_API_KEY_ANDROID"] ?: ""

android {
    namespace = "ph.edu.tip.novaride"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "ph.edu.tip.novaride"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY_ANDROID"] = googleMapsApiKeyAndroid
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
