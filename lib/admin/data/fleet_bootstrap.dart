import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:novaride/admin/data/admin_auth.dart';
import 'package:novaride/admin/data/firebase_admin_auth.dart';
import 'package:novaride/admin/data/firestore_fleet_repository.dart';
import 'package:novaride/admin/data/firestore_seed.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/data/mock_fleet_repository.dart';
import 'package:novaride/admin/state/admin_session.dart';

/// What [FleetBootstrap.resolve] decided, handed to `AdminApp` in one piece.
///
/// Data source and sign-in provider travel together on purpose: they are one
/// decision, not two. A console that read live Firestore data behind a
/// string-comparison login, or verified real operators and then showed them
/// the simulation, would be lying in one direction or the other.
class ConsoleBackend {
  /// Source for the fleet data.
  final FleetRepositoryFactory createRepository;

  /// Who verifies sign-ins. `FirebaseAdminAuth` alongside Firestore;
  /// [LocalAdminAuth] — the demo accounts — alongside the simulation.
  final AdminAuth auth;

  /// Firebase project the console initialised against — read from the loaded
  /// config, never written down elsewhere, so the UI cannot name a project
  /// other than the one it is talking to. Null on the simulation, which has
  /// no project.
  final String? projectId;

  const ConsoleBackend({
    required this.createRepository,
    required this.auth,
    this.projectId,
  });

  /// The in-process simulation, exactly as the console ran before Firebase.
  ConsoleBackend.simulation()
      : this(createRepository: MockFleetRepository.new, auth: LocalAdminAuth());
}

/// Decides, once at startup, where the console's fleet data comes from and
/// who signs operators in.
///
/// The rule is simple so it can be trusted during a demo: if
/// `assets/config/firebase.json` is present and Firebase initialises, the
/// console runs on Cloud Firestore with Firebase Auth; otherwise it runs on
/// the in-process simulation with the local demo accounts, exactly as it did
/// before Firebase existed. The file is gitignored, so a fresh clone is a
/// simulation build with no extra steps — nothing here can break a teammate
/// who has never touched Firebase.
///
/// The choice is surfaced as a chip in the admin top bar. It is never
/// silent: a configured build that falls back prints why to the console.
class FleetBootstrap {
  const FleetBootstrap._();

  /// Web config in the shape `firebase apps:sdkconfig WEB` prints.
  static const configAsset = 'assets/config/firebase.json';

  /// `--dart-define=NOVARIDE_FORCE_SIMULATION=true` keeps a configured
  /// machine on the simulation, for offline rehearsals.
  static const forceSimulation =
      bool.fromEnvironment('NOVARIDE_FORCE_SIMULATION');

  /// `--dart-define=SEED_FIRESTORE=true` writes the simulation's seed fleet
  /// into an empty Firestore once a Super Admin signs in. Never automatic;
  /// see [seedAfterSignIn] and [seedFirestore].
  static const seedRequested = bool.fromEnvironment('SEED_FIRESTORE');

  /// Returns the backend `AdminApp` should mount. Safe to call before
  /// `runApp`; requires `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<ConsoleBackend> resolve() async {
    if (forceSimulation) {
      debugPrint('FleetBootstrap: NOVARIDE_FORCE_SIMULATION set — simulation.');
      return ConsoleBackend.simulation();
    }

    final options = await _loadOptions();
    if (options == null) return ConsoleBackend.simulation();

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
    } catch (error) {
      debugPrint('FleetBootstrap: Firebase failed to initialise — $error. '
          'Falling back to the simulation.');
      return ConsoleBackend.simulation();
    }

    if (seedRequested) {
      debugPrint('FleetBootstrap: SEED_FIRESTORE set — the seed runs after a '
          'Super Admin signs in.');
    }

    debugPrint('FleetBootstrap: Cloud Firestore (${options.projectId}).');
    return ConsoleBackend(
      createRepository: FirestoreFleetRepository.new,
      auth: FirebaseAdminAuth(),
      projectId: options.projectId,
    );
  }

  /// Runs the one-time seed, if requested, now that [user] is signed in.
  ///
  /// The seed used to run before `runApp`. It cannot any more: the security
  /// rules accept writes to `riders/`, `devices/` and `alerts/` only from a
  /// signed-in Super Admin, and before sign-in there is no principal at all.
  /// The shell calls this once per session; it is a no-op unless
  /// `SEED_FIRESTORE=true`, Firebase is up, and [user] is a Super Admin.
  /// Outcome goes to the debug console, as before.
  static Future<void> seedAfterSignIn(AdminUser user) async {
    if (!seedRequested || Firebase.apps.isEmpty) return;
    if (user.role != AdminRole.superAdmin) {
      debugPrint('FleetBootstrap: SEED_FIRESTORE set, but ${user.email} is a '
          '${user.role.label} — only a Super Admin may seed. Skipped.');
      return;
    }
    try {
      await seedFirestore();
    } catch (error) {
      debugPrint('FleetBootstrap: seed failed — $error');
    }
  }

  /// Null when the asset is absent or not a usable config. Absence is the
  /// normal state for a checkout without credentials, so it is logged
  /// quietly rather than treated as an error.
  static Future<FirebaseOptions?> _loadOptions() async {
    final String raw;
    try {
      // Ask the manifest first: a bare loadString on a missing asset makes
      // the web engine log a 404 as an error, which reads as a fault when it
      // is the expected state of a checkout without credentials.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (!manifest.listAssets().contains(configAsset)) {
        debugPrint('FleetBootstrap: no $configAsset — simulation.');
        return null;
      }
      raw = await rootBundle.loadString(configAsset);
    } catch (_) {
      debugPrint('FleetBootstrap: no $configAsset — simulation.');
      return null;
    }

    try {
      final json = jsonDecode(raw);
      if (json is! Map) throw const FormatException('not a JSON object');
      final map = json.cast<String, dynamic>();

      String need(String key) {
        final value = map[key];
        if (value is! String || value.isEmpty) {
          throw FormatException('missing "$key"');
        }
        return value;
      }

      final apiKey = need('apiKey');
      if (apiKey.startsWith('AIza-your')) {
        throw const FormatException('still the example placeholder');
      }

      return FirebaseOptions(
        apiKey: apiKey,
        appId: need('appId'),
        messagingSenderId: need('messagingSenderId'),
        projectId: need('projectId'),
        authDomain: map['authDomain'] as String?,
        storageBucket: map['storageBucket'] as String?,
        measurementId: map['measurementId'] as String?,
      );
    } catch (error) {
      debugPrint('FleetBootstrap: $configAsset is unusable ($error) — '
          'simulation.');
      return null;
    }
  }
}
