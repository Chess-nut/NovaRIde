import 'package:flutter/material.dart';
import 'emergency_contact/screens/emergency_alert_page.dart';
import 'emergency_contact/screens/incident_history_page.dart';
import 'emergency_contact/screens/rider_dashboard_page.dart';
import 'emergency_contact/screens/rider_map_page.dart';
import 'emergency_contact/screens/profile_page.dart';
import 'shared/theme.dart';
import 'rider/screens/welcome_page.dart';

/// Rider mobile app entrypoint.
/// The TNVS operations dashboard has its own entrypoint: lib/main_admin.dart.
void main() {
  runApp(const NovaRideApp());
}

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