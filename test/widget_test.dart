// Smoke test for the NovaRide rider app entrypoint.
//
// Replaces the stock Flutter counter test, which referenced a `MyApp` class
// this project no longer has.

import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/main.dart';

void main() {
  testWidgets('rider app boots to the login page', (WidgetTester tester) async {
    await tester.pumpWidget(const NovaRideApp());

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });
}
