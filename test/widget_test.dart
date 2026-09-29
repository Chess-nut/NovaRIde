// Smoke test for the NovaRide mobile entrypoint.
//
// The app boots through the splash into the Welcome screen (brand, three
// feature pills, GET STARTED, Log In), not the login page — the login page
// is two taps in, behind Select User Type. The screens moved into
// lib/features/ in Phase 1 and the app now routes with go_router under a
// ProviderScope; what the person sees is unchanged, and that is what these
// assertions are for.

import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/features/auth/presentation/pages/login_page.dart';
import 'package:novaride/features/onboarding/presentation/pages/role_selection_page.dart';
import 'package:novaride/features/onboarding/presentation/pages/welcome_page.dart';

import 'support/mobile_app.dart';

void main() {
  silenceAppLogger();

  testWidgets('mobile app boots to the welcome page', (tester) async {
    await pumpMobileApp(tester);

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('GET STARTED leads to Select User Type', (tester) async {
    await pumpMobileApp(tester);

    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();

    expect(find.byType(RoleSelectionPage), findsOneWidget);
    expect(find.text('Motorcycle Rider'), findsOneWidget);
    expect(find.text('Family / Emergency Contact'), findsOneWidget);
  });

  testWidgets('Log In opens the login page', (tester) async {
    await pumpMobileApp(tester);

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });
}
