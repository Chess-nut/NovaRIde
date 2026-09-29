import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'shared/maps/google_maps_key.dart';
import 'shared/maps/google_maps_script.dart';

/// Rider and guardian mobile app entrypoint.
/// The TNVS operations dashboard has its own entrypoint: lib/main_admin.dart,
/// which shares none of this app's state management.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web only; a no-op on Android. Android and iOS take their key from
  // native config at build time (see lib/shared/maps/google_maps_key.dart).
  await loadGoogleMapsScript(googleMapsApiKeyWeb);
  runApp(const ProviderScope(child: NovaRideApp()));
}
