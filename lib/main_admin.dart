import 'package:flutter/material.dart';
import 'admin/data/admin_auth.dart';
import 'admin/data/fleet_bootstrap.dart';
import 'admin/data/fleet_repository.dart';
import 'admin/data/mock_fleet_repository.dart';
import 'admin/screens/admin_login_page.dart';
import 'admin/state/fleet_scope.dart';
import 'shared/theme.dart';

/// TNVS Operator console.
///
/// The backend is decided once, here, before the first frame: Cloud
/// Firestore with Firebase Auth when `assets/config/firebase.json` is present
/// and Firebase initialises, the in-process simulation with the local demo
/// accounts otherwise. See [FleetBootstrap].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await FleetBootstrap.resolve();
  runApp(AdminApp(
    createRepository: backend.createRepository,
    auth: backend.auth,
    projectId: backend.projectId,
  ));
}

class AdminApp extends StatefulWidget {
  /// Source for the fleet data. Null — the widget tests' case — means the
  /// simulation, so a test never reaches for the network.
  final FleetRepositoryFactory? createRepository;

  /// Who verifies sign-ins. Null means the local demo accounts, for the same
  /// reason.
  final AdminAuth? auth;

  /// Firebase project the data comes from, for the top bar's tooltip. Null on
  /// the simulation.
  final String? projectId;

  const AdminApp({
    super.key,
    this.createRepository,
    this.auth,
    this.projectId,
  });

  @override
  State<AdminApp> createState() => _AdminAppState();
}

/// Stateful for one reason: the [AdminAuth] must be a single instance for
/// the life of the app. The login page signs in through it and the shell
/// subscribes to it; a rebuild that handed them two different instances
/// would leave the shell listening to an auth nobody signs out of.
class _AdminAppState extends State<AdminApp> {
  late final AdminAuth _auth = widget.auth ?? LocalAdminAuth();

  @override
  Widget build(BuildContext context) {
    return FleetSourceScope(
      createRepository: widget.createRepository ?? MockFleetRepository.new,
      auth: _auth,
      projectId: widget.projectId,
      child: MaterialApp(
        title: 'NovaRide Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: NovaColors.background,
          fontFamily: 'Roboto',
        ),
        home: const AdminLoginPage(),
      ),
    );
  }
}
