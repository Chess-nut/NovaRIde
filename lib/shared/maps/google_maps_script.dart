/// Loads the Maps JavaScript API on the web. A no-op everywhere else.
///
/// `google_maps_flutter_web` expects `google.maps` to exist when a map is
/// first built, and the usual way to arrange that is a `<script>` tag in
/// web/index.html — which is where this project's key used to be committed.
/// Injecting the tag from Dart instead lets the key travel with the build's
/// `--dart-define`s like the Android one does.
///
/// Conditional import: the web file needs `package:web`, which does not
/// compile on Android or in `flutter test`.
library;

export 'google_maps_script_stub.dart'
    if (dart.library.js_interop) 'google_maps_script_web.dart';
