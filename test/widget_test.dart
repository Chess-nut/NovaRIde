// Smoke test for the NovaRide rider app entrypoint.
//
// Replaces the stock Flutter counter test, which referenced a `MyApp` class
// this project no longer has.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/main.dart';
import 'package:novaride/rider/screens/home_page.dart';

void main() {
  testWidgets('rider app boots to the login page', (WidgetTester tester) async {
    await tester.pumpWidget(const NovaRideApp());

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });

  testWidgets('home page does not expose an alerts navigation connection', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('ALERTS'), findsNothing);
    expect(find.text('NOVARIDE'), findsOneWidget);
  });
}
