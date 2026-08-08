// Exercises the admin dashboard the way the Phase 1 acceptance check does:
// sign in with the mock credentials, then visit every nav page and confirm
// each one builds without throwing (overflows included).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/admin/widgets/dashboard/recent_alerts_feed_panel.dart';
import 'package:novaride/main_admin.dart';

/// Desktop-sized surface — the shell is designed for >= 1280px.
Future<void> _useDesktopSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The dashboard runs a looping pulse animation and two simulation timers, so
/// it never settles. Every post-login pump is an explicit duration instead.
///
/// The one-second pump also outlasts the route transition — while it is
/// running the login page is still mounted, and its demo-credentials card
/// carries the same role labels as the top bar.
Future<void> _signIn(
  WidgetTester tester, {
  String email = 'admin@novaride.ph',
  String password = 'admin123',
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.tap(find.text('SIGN IN'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Unmounts the shell so the dashboard's timers are cancelled — flutter_test
/// fails the test if any are still pending, which is the leak check.
Future<void> _tearDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
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
    expect(find.text('TYPE OF RIDER STATUS'), findsNothing);
  });

  testWidgets('mock login reaches the six-panel operations grid',
      (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    for (final title in [
      'TYPE OF RIDER STATUS',
      'ALERTS BY AREA',
      'LIVE FLEET MAP',
      'RECENT ALERT',
      'ALERT PRIORITY',
      'ALERT TYPES',
    ]) {
      expect(find.text(title), findsOneWidget, reason: '$title panel missing');
    }

    // Donut centre and map badge both count the whole mock fleet.
    expect(find.text('10'), findsOneWidget);
    expect(find.text('10 helmets'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tearDownTree(tester);
  });

  testWidgets('simulation spawns a new alert into the feed', (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    final before = tester.widgetList<Text>(find.byType(Text)).length;

    // Alerts arrive every 10–14s, so 15s guarantees at least one.
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(
      tester.widgetList<Text>(find.byType(Text)).length,
      greaterThan(before),
      reason: 'no alert was prepended to the feed',
    );

    await _tearDownTree(tester);
  });

  testWidgets('every nav page renders without exceptions', (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    for (final label in [
      'Rider Monitoring',
      'User Management',
      'Alerts',
      'Reports',
      'Dashboard',
    ]) {
      await tester.tap(find.text(label).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '$label threw on render');
    }

    // Landed back on the dashboard.
    expect(find.text('LIVE FLEET MAP'), findsOneWidget);

    await _tearDownTree(tester);
  });

  testWidgets('narrow viewport stacks the panels without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    expect(find.text('TYPE OF RIDER STATUS'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tearDownTree(tester);
  });

  testWidgets('logout returns to the login page', (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('NovaRide TNVS Operations'), findsOneWidget);
  });

  // ------------------------------------------------------------ role gating

  testWidgets('super admin reaches all five tabs', (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    expect(find.text('User Management'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Ops Admin'), findsOneWidget);
    expect(find.text('SUPER ADMIN'), findsOneWidget);

    await _tearDownTree(tester);
  });

  testWidgets('dispatcher cannot see User Management', (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(
      tester,
      email: 'dispatch@novaride.ph',
      password: 'dispatch123',
    );

    expect(find.text('User Management'), findsNothing);
    expect(find.text('Marisol Cruz'), findsOneWidget);
    expect(find.text('DISPATCHER'), findsOneWidget);

    await _tearDownTree(tester);
  });

  testWidgets('viewer sees the alerts board but cannot act on it',
      (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester, email: 'viewer@novaride.ph', password: 'viewer123');

    expect(find.text('User Management'), findsNothing);
    expect(find.text('Ramon Bautista'), findsOneWidget);

    await tester.tap(find.text('Alerts').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(AlertFeedTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Viewer cannot act on alerts'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tearDownTree(tester);
  });

  /// The trap this guards: a role-filtered nav list and a static page list
  /// would desynchronise, so the title would name a different tab than the
  /// one on screen.
  testWidgets('top bar title matches the visible page for every role',
      (tester) async {
    for (final account in [
      ('admin@novaride.ph', 'admin123'),
      ('dispatch@novaride.ph', 'dispatch123'),
      ('viewer@novaride.ph', 'viewer123'),
    ]) {
      await _useDesktopSurface(tester);
      await tester.pumpWidget(const AdminApp());
      await _signIn(tester, email: account.$1, password: account.$2);

      // Reports is the last tab, so its index shifts for filtered roles.
      await tester.tap(find.text('Reports').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Operations report'),
        findsOneWidget,
        reason: '${account.$1} landed on the wrong page from Reports',
      );

      await tester.tap(find.text('Rider Monitoring').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Select a rider'),
        findsOneWidget,
        reason: '${account.$1} landed on the wrong page from Monitoring',
      );

      expect(tester.takeException(), isNull);
      await _tearDownTree(tester);
    }
  });

  // ------------------------------------------------------- shared fleet state

  testWidgets('alerts page tracks the same live feed as the dashboard',
      (tester) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(const AdminApp());
    await _signIn(tester);

    await tester.tap(find.text('Alerts').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Seeded board, before the simulation adds anything.
    expect(find.text('5 shown'), findsOneWidget);

    // Sit on the alerts tab while an alert spawns; the shared controller
    // means it lands here, not only on the dashboard.
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('5 shown'), findsNothing);

    await _tearDownTree(tester);
  });

  test('feed timestamps render in the reference format', () {
    expect(
      RecentAlertsFeedPanel.formatStamp(DateTime(2026, 7, 30, 14, 28)),
      '7/30/2026, 2:28 PM',
    );
    expect(
      RecentAlertsFeedPanel.formatStamp(DateTime(2026, 7, 30, 0, 5)),
      '7/30/2026, 12:05 AM',
    );
  });
}
