import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Appends `<script src="https://maps.googleapis.com/maps/api/js?key=…">` to
/// the document head and resolves once it has loaded.
///
/// An empty [apiKey] is the normal state of a checkout without credentials:
/// it is logged once and the map page will render blank tiles, which is
/// preferable to a build that cannot start. A script that fails to load —
/// offline, or a key the referrer restriction rejects — is logged the same
/// way and never throws out of startup.
Future<void> loadGoogleMapsScript(String apiKey) async {
  if (apiKey.isEmpty) {
    debugPrint('GoogleMaps: GOOGLE_MAPS_API_KEY_WEB not set — maps will not '
        'render on web. Pass it with --dart-define (see lib/shared/maps/).');
    return;
  }

  final loaded = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(apiKey)}'
    ..async = true
    ..onload = ((web.Event _) => loaded.complete()).toJS
    ..onerror = ((web.Event _) => loaded.completeError(
          StateError('the Maps JavaScript API script failed to load'),
        )).toJS;
  web.document.head!.append(script);

  try {
    await loaded.future;
  } on StateError catch (error) {
    // Deliberately not rethrown: the map is one screen, not the app.
    debugPrint('GoogleMaps: $error — maps will not render on web.');
  }
}
