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
const String googleMapsApiKeyWeb = String.fromEnvironment('GOOGLE_MAPS_API_KEY_WEB');
