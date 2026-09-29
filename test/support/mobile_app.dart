// Pumping the mobile app in a chosen session state.
//
// NovaRideApp reads its router from a provider, so a test has to supply a
// ProviderScope. This helper supplies one and lets the test say what the
// session is, which is the whole point of the placeholder
// authStateProvider: the splash -> gate -> home behaviour can be exercised
// now, before any Firebase implementation exists.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:novaride/app/app.dart';
import 'package:novaride/core/utils/app_logger.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';

/// An AuthController pinned to one state, for overriding the real one.
class FixedAuthController extends AuthController {
  FixedAuthController(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

/// Pumps the app with [auth] as the session. Omit it for the default the
/// app ships with (signed out).
///
/// [settle] is false for any state that lands on the splash: its progress
/// indicator animates forever, so `pumpAndSettle` would time out rather
/// than tell you anything. Two frames are enough for go_router to parse
/// the initial location, run the redirect and build the destination.
Future<void> pumpMobileApp(
  WidgetTester tester, {
  AuthState? auth,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (auth != null)
          authStateProvider.overrideWith(() => FixedAuthController(auth)),
      ],
      child: const NovaRideApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A profile to sign a test in as. Nothing reads these values yet beyond
/// the role, which is what picks the home screen.
UserProfile profileFor(
  UserRole role, {
  String uid = 'uid-test',
  bool emailVerified = true,
}) =>
    UserProfile(
      uid: uid,
      email: 'test@example.test',
      username: 'testrider',
      fullName: 'Test Person',
      role: role,
      emailVerified: emailVerified,
    );

/// Turns AppLogger off for the duration of a test file.
///
/// The router logs every redirect at debug level, which is useful when
/// running the app and pure noise in a test run. Call from `setUpAll`.
void silenceAppLogger() {
  setUpAll(() => AppLogger.useLogger(Logger(level: Level.off)));
  tearDownAll(AppLogger.reset);
}
