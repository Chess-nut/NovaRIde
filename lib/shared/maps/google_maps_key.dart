/// The Maps JavaScript API key for the web build, supplied at build time:
///
///     flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY_WEB=<key>
///
/// or `--dart-define-from-file=dart_defines.local.json` (gitignored; see
/// dart_defines.example.json). Android reads `GOOGLE_MAPS_API_KEY_ANDROID`
/// from the same defines in android/app/build.gradle.kts, and iOS reads
/// `GOOGLE_MAPS_API_KEY_IOS` from ios/Flutter/Secrets.xcconfig. They are three
/// keys, not one: Google Cloud lets a key carry a single application
/// restriction — HTTP referrers, or an Android package + SHA-1, or an iOS
/// bundle id — so a key locked to one platform cannot serve another.
///
/// Empty when not supplied. Nothing in the repository holds a key.
library;

import 'package:flutter/foundation.dart';

/// The Maps JavaScript API key for the web build.
const String googleMapsApiKeyWeb = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY_WEB',
);

/// The Android key, from the same defines. Gradle puts it in the manifest
/// for the Maps SDK; Dart reads it only to know whether there is one.
const String googleMapsApiKeyAndroid = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY_ANDROID',
);

/// iOS reads its key from Secrets.xcconfig, which Dart cannot see. Add the
/// same key under this name in dart_defines.local.json to turn the map on.
const String googleMapsApiKeyIos = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY_IOS',
);

/// Whether this build was given a Maps key for the platform it runs on.
///
/// Without one the map screens draw their street-grid stand-in rather
/// than a blank grey Google map. Tests are built without keys, so they
/// always get the drawing and never touch the Maps platform view.
bool get googleMapsAvailable {
  if (kIsWeb) return googleMapsApiKeyWeb.isNotEmpty;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => googleMapsApiKeyAndroid.isNotEmpty,
    TargetPlatform.iOS => googleMapsApiKeyIos.isNotEmpty,
    _ => false,
  };
}
