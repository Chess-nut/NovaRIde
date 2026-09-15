import 'package:flutter/material.dart';
import 'admin/data/fleet_bootstrap.dart';
import 'admin/data/fleet_repository.dart';
import 'admin/screens/admin_login_page.dart';
import 'admin/state/fleet_scope.dart';
import 'shared/theme.dart';

/// TNVS Operator console.
///
/// The data source is decided once, here, before the first frame: Cloud
/// Firestore when `assets/config/firebase.json` is present and Firebase
/// initialises, the in-process simulation otherwise. See [FleetBootstrap].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final createRepository = await FleetBootstrap.resolve();
  runApp(AdminApp(createRepository: createRepository));
}

class AdminApp extends StatelessWidget {
  /// Source for the fleet data. Null — the widget tests' case — means the
  /// simulation, so a test never reaches for the network.
  final FleetRepositoryFactory? createRepository;

  const AdminApp({super.key, this.createRepository});

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'NovaRide Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NovaColors.background,
        fontFamily: 'Roboto',
      ),
      home: const AdminLoginPage(),
    );

    final create = createRepository;
    if (create == null) return app;
    return FleetSourceScope(createRepository: create, child: app);
  }
}
