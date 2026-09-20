// Layout at the size a defence actually runs at: a 1280×720 projector with a
// browser's chrome taken off the top. Every page is visited on an empty
// backend — the state a freshly provisioned Firestore project is in — and on
// the simulation, and must render without a RenderFlex overflow. The real
// font is loaded because the test font's wide glyphs wrap copy that Roboto
// keeps on one line, which would hide a failure or invent one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/data/admin_auth.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/state/admin_session.dart';
import 'package:novaride/main_admin.dart';
import 'package:novaride/shared/models/models.dart';

import 'support/roboto.dart';

/// A Firestore-shaped backend with nothing in it: streams that answer at
/// once with empty lists, as a project does before the seed runs.
class _EmptyRepository implements FleetRepository {
  @override
  FleetSource get source => FleetSource.firestore;

  @override
  Stream<List<Rider>> watchRiders() => Stream.value(const []);
  @override
  Stream<List<HelmetTelemetry>> watchTelemetry() => Stream.value(const []);
  @override
  Stream<List<AlertEvent>> watchAlerts() => Stream.value(const []);
  @override
  Stream<FleetConnection> watchConnection() =>
      Stream.value(FleetConnection.connected);

  @override
  Future<Rider> addRider(Rider rider) async => rider;
  @override
  Future<void> updateRider(Rider rider) async {}
  @override
  Future<void> setRiderActive(String riderId, bool active) async {}
  @override
  Future<void> setRiderStatus(String riderId, RiderStatus status) async {}
  @override
  Future<void> transitionAlert(String alertId, AlertAction action) async {}
  @override
  void dispose() {}
}

/// Signs anyone in as a Super Admin, so every tab is on the nav.
class _SuperAdminAuth implements AdminAuth {
  final _changes = StreamController<AdminUser?>.broadcast();
  AdminUser? _current;

  static const _user = AdminUser(
    name: 'Layout Tester',
    email: 'layout@tip.edu.ph',
    role: AdminRole.superAdmin,
  );

  @override
  AdminUser? get currentUser => _current;
  @override
  Stream<AdminUser?> authStateChanges() => _changes.stream;
  @override
  Future<AdminUser> signIn(String email, String password) async {
    _current = _user;
    _changes.add(_user);
    return _user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _changes.add(null);
  }

  void dispose() => _changes.close();
}

const _tabs = [
  'Dashboard',
  'Rider Monitoring',
  'Alerts',
  'Reports',
  'User Management',
];

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, 'layout@tip.edu.ph');
  await tester.enterText(find.byType(TextFormField).last, 'whatever');
  await tester.pump();
  await tester.tap(find.text('SIGN IN'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Visits every tab and fails on the first one that throws while laying
/// out — a RenderFlex overflow is reported as an exception under test.
/// [onTab] runs while each tab is showing, for assertions about its content.
Future<void> _visitEveryTab(
  WidgetTester tester, {
  required String on,
  void Function(String tab)? onTab,
}) async {
  for (final tab in _tabs) {
    await tester.tap(find.text(tab).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final error = tester.takeException();
    expect(error, isNull, reason: '$tab overflowed or threw on $on: $error');
    onTab?.call(tab);
  }
}

/// 720p projector (the observed failure), the 1366×768 laptop that mirrors
/// it, and a step wider. 1280 renders the pages' scrolling layouts; 1366
/// and 1440 cross into the fixed-height ones, which is where a short
/// viewport can bite. 633 and 657 are what two browsers leave of 720 rows;
/// 560 leaves the Alerts queue less room than its empty state needs, so the
/// message must scroll rather than overflow; 500 is short enough that the
/// page falls back to scrolling as a whole.
const _surfaces = [
  Size(1280, 633),
  Size(1366, 633),
  Size(1440, 633),
  Size(1366, 657),
  Size(1366, 560),
  Size(1366, 500),
];

Future<void> _tearDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  for (final size in _surfaces) {
    final label = '${size.width.toInt()}×${size.height.toInt()}';

    testWidgets('every page renders its empty state at $label without '
        'overflowing', (tester) async {
      await useProjectorSurface(tester, size);
      final auth = _SuperAdminAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        AdminApp(auth: auth, createRepository: _EmptyRepository.new),
      );
      await _signIn(tester);
      expect(tester.takeException(), isNull,
          reason: 'first page after sign-in');

      await _visitEveryTab(
        tester,
        on: 'an empty Firestore at $label',
        onTab: (tab) {
          if (tab == 'Alerts') {
            expect(find.text('No alerts match these filters'), findsOneWidget,
                reason: 'the empty state is what this test is about');
          }
        },
      );

      await _tearDownTree(tester);
    }, skip: !hasRoboto);
  }

  testWidgets('every page renders the simulation at 1280×633 without '
      'overflowing', (tester) async {
    await useProjectorSurface(tester, projectorSize);
    await tester.pumpWidget(const AdminApp());
    await tester.enterText(
        find.byType(TextFormField).first, 'admin@novaride.ph');
    await tester.enterText(find.byType(TextFormField).last, 'admin123');
    await tester.pump();
    await tester.tap(find.text('SIGN IN'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull, reason: 'first page after sign-in');

    await _visitEveryTab(tester, on: 'the simulation');

    await _tearDownTree(tester);
  }, skip: !hasRoboto);
}
