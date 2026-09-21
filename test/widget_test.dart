// Smoke test for the NovaRide rider app entrypoint.
//
// The app boots to the Welcome screen (brand, three feature pills, GET
// STARTED, Log In), not the login page — the login page is two taps in,
// behind Select User Type.

import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/main.dart';
import 'package:novaride/rider/screens/login_page.dart';
import 'package:novaride/rider/screens/role_selection_page.dart';
import 'package:novaride/rider/screens/welcome_page.dart';

void main() {
  testWidgets('rider app boots to the welcome page', (tester) async {
    await tester.pumpWidget(const NovaRideApp());

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('GET STARTED leads to Select User Type', (tester) async {
    await tester.pumpWidget(const NovaRideApp());

    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();

    expect(find.byType(RoleSelectionPage), findsOneWidget);
    expect(find.text('Motorcycle Rider'), findsOneWidget);
    expect(find.text('Family / Emergency Contact'), findsOneWidget);
  });

  testWidgets('Log In opens the login page', (tester) async {
    await tester.pumpWidget(const NovaRideApp());

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });
}
