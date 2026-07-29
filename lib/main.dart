import 'package:flutter/material.dart';
import 'shared/theme.dart';
import 'rider/screens/login_page.dart';

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
      home: const LoginPage(),
    );
  }
}
