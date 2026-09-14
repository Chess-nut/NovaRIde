import 'package:flutter/material.dart';
import 'family/screens/family_dashboard_page.dart';
import 'family/screens/family_emergency_alert_page.dart';
import 'family/screens/family_incident_history_page.dart';
import 'family/screens/family_live_location_page.dart';
import 'family/screens/family_monitoring_page.dart';
import 'family/screens/family_profile_page.dart';
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
        '/family-dashboard': (_) => const FamilyDashboardPage(),
        '/family-monitoring': (_) => const FamilyMonitoringPage(),
        '/family-map': (_) => const FamilyLiveLocationPage(),
        '/family-alerts': (_) => const FamilyEmergencyAlertPage(),
        '/family-history': (_) => const FamilyIncidentHistoryPage(),
        '/family-profile': (_) => const FamilyProfilePage(),
      },
    );
  }
}