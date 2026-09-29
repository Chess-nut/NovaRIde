// Smoke test for the NovaRide mobile entrypoint.
//
// The app boots through the splash into the Welcome screen, and the login
// page is two taps in, behind Select User Type. That shape is unchanged
// since before Phase 1; the copy is not. Phase 2's redesign (direction
// Signal) moved the app off tracked capitals — "GET STARTED" is now "Get
// started" — so these assertions were updated to the new wording rather
// than the screens being held to the old.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

<<<<<<< HEAD
import 'package:novaride/features/auth/presentation/pages/login_page.dart';
import 'package:novaride/features/onboarding/presentation/pages/role_selection_page.dart';
import 'package:novaride/features/onboarding/presentation/pages/welcome_page.dart';

import 'support/mobile_app.dart';
=======
import 'package:novaride/main.dart';
import 'package:novaride/rider/screens/home_page.dart';
>>>>>>> origin/main

void main() {
  silenceAppLogger();

  testWidgets('mobile app boots to the welcome page', (tester) async {
    await pumpMobileApp(tester);

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('the welcome screen names what the helmet does', (tester) async {
    await pumpMobileApp(tester);

    expect(find.text('Crash detection'), findsOneWidget);
    expect(find.text('Instant SOS'), findsOneWidget);
    expect(find.text('Live tracking'), findsOneWidget);
  });

  testWidgets('Get started leads to Select User Type', (tester) async {
    await pumpMobileApp(tester);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.byType(RoleSelectionPage), findsOneWidget);
    expect(find.text('Motorcycle Rider'), findsOneWidget);
    expect(find.text('Family / Emergency Contact'), findsOneWidget);
  });

  testWidgets('Log in opens the login page', (tester) async {
    await pumpMobileApp(tester);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('home page does not expose an alerts navigation connection', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('ALERTS'), findsNothing);
    expect(find.text('NOVARIDE'), findsOneWidget);
  });
}
