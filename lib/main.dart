import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:flutter_riverpod/flutter_riverpod.dart';
=======
import 'emergency_contact/screens/emergency_alert_page.dart';
import 'emergency_contact/screens/incident_history_page.dart';
import 'emergency_contact/screens/rider_dashboard_page.dart';
import 'emergency_contact/screens/rider_map_page.dart';
import 'emergency_contact/screens/profile_page.dart';
import 'shared/theme.dart';
import 'rider/screens/welcome_page.dart';
>>>>>>> origin/main

import 'app/app.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';
import 'shared/maps/google_maps_script.dart';
import 'shared/maps/google_maps_key.dart';

/// Rider and guardian mobile app entrypoint.
///
/// The TNVS operations dashboard has its own entrypoint,
/// lib/main_admin.dart, which shares none of this app's state management
/// and reads its Firebase config from an asset at runtime rather than
/// from [DefaultFirebaseOptions].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Before anything reads FirebaseAuth or Firestore. If this throws the
  // app cannot do anything useful, so it is not caught: a crash at launch
  // with a real stack trace beats a login screen that silently refuses
  // every attempt.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AppLogger.i('Firebase ready: ${Firebase.app().options.projectId}');

  // Web only; a no-op on Android. Android and iOS take their key from
  // native config at build time (see lib/shared/maps/google_maps_key.dart).
  await loadGoogleMapsScript(googleMapsApiKeyWeb);

  runApp(const ProviderScope(child: NovaRideApp()));
}
<<<<<<< HEAD
=======

class NovaRideApp extends StatelessWidget {
  const NovaRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NovaRide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NovaColors.background,
        fontFamily: 'Roboto',
      ),
      home: const WelcomePage(),
      routes: {
        '/emergency-dashboard': (_) => const RiderDashboardPage(),
        '/emergency-map': (_) => const RiderMapPage(),
        '/emergency-alerts': (_) => const EmergencyAlertPage(),
        '/emergency-history': (_) => const IncidentHistoryPage(),
        '/emergency-profile': (_) => const ProfilePage(),
      },
    );
  }
}
>>>>>>> origin/main
