import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void>? _scriptLoad;

/// Appends `<script src="https://maps.googleapis.com/maps/api/js?key=…">` to
/// the document head and resolves once it has loaded.
///
/// Failures are surfaced to the map screen instead of building a GoogleMap
/// without the JavaScript API it requires.
Future<void> loadGoogleMapsScript(String apiKey) async {
  if (apiKey.trim().isEmpty) {
    throw StateError(
      'GOOGLE_MAPS_API_KEY_WEB is not set. Start the web app with '
      '--dart-define=GOOGLE_MAPS_API_KEY_WEB=<key>.',
    );
  }
  final existingLoad = _scriptLoad;
  if (existingLoad != null) {
    try {
      await existingLoad;
      return;
    } catch (_) {
      _scriptLoad = null;
      rethrow;
    }
  }

  final loaded = Completer<void>();
  _scriptLoad = loaded.future;
  final script = web.HTMLScriptElement()
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(apiKey)}'
    ..async = true
    ..onload = ((web.Event _) => loaded.complete()).toJS
    ..onerror = ((web.Event _) => loaded.completeError(
      StateError(
        'The Maps JavaScript API failed to load. Check the key, API '
        'enablement, authorized referrers, and network connection.',
      ),
    )).toJS;
  web.document.head!.append(script);
  try {
    await loaded.future;
  } catch (error, stackTrace) {
    _scriptLoad = null;
    Error.throwWithStackTrace(error, stackTrace);
  }
}
