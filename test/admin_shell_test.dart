// Exercises the admin dashboard the way the Phase 1 acceptance check does:
// sign in with the mock credentials, then visit every nav page and confirm
// each one builds without throwing (overflows included).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/main_admin.dart';

/// Desktop-sized surface — the shell is designed for >= 1280px.
Future<void> _useDesktopSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, 'admin@novaride.ph');
  await tester.enterText(find.byType(TextFormField).last, 'admin123');
  await tester.tap(find.text('SIGN IN'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('admin app boots to the operations login', (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());

    expect(find.text('NovaRide TNVS Operations'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('wrong credentials show an inline error banner', (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());

    await tester.enterText(find.byType(TextFormField).first, 'nope@novaride.ph');
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.text('Live Fleet'), findsNothing);
  });

  testWidgets('mock login reaches the dashboard with computed KPIs',
      (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    expect(find.text('Live Fleet'), findsOneWidget);
    expect(find.text('Active Riders'), findsOneWidget);
    expect(find.text('Open Alerts'), findsOneWidget);
    expect(find.text('Alerts this week'), findsOneWidget);

    // 5 riding + 1 emergency in the mock fleet.
    expect(find.text('6'), findsWidgets);
    // 8 of 10 helmets are not offline.
    expect(find.text('of 10 registered helmets'), findsOneWidget);
  });

  testWidgets('every nav page renders without exceptions', (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    for (final label in [
      'Rider Monitoring',
      'User Management',
      'Alerts',
      'Dashboard',
    ]) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$label threw on render');
    }

    // Landed back on the dashboard.
    expect(find.text('Live Fleet'), findsOneWidget);
  });

  testWidgets('logout returns to the login page', (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('NovaRide TNVS Operations'), findsOneWidget);
  });
}
