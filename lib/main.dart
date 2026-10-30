import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';

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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.i('Firebase ready: ${Firebase.app().options.projectId}');

  runApp(const ProviderScope(child: NovaRideApp()));
}
