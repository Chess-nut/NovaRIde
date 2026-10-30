// The Alerts page against a store that refuses or breaks mid-write. The
// operator must get a sentence written for them — a FleetWriteException's
// message, or one fixed fallback — and never the exception's own text, which
// on the Firestore path would carry a provider code and a document path.
// Nothing here touches Firebase.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/data/admin_auth.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/state/admin_session.dart';
import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/main_admin.dart';
import 'package:novaride/shared/models/models.dart';

class _ScriptedRepository implements FleetRepository {
  final riders = StreamController<List<Rider>>.broadcast();
  final telemetry = StreamController<List<HelmetTelemetry>>.broadcast();
  final alerts = StreamController<List<AlertEvent>>.broadcast();
  final connection = StreamController<FleetConnection>.broadcast();

  /// What [transitionAlert] throws instead of succeeding.
  Object? failWith;

  @override
  FleetSource get source => FleetSource.firestore;
  @override
  Stream<List<Rider>> watchRiders() => riders.stream;
  @override
  Stream<List<HelmetTelemetry>> watchTelemetry() => telemetry.stream;
  @override
  Stream<List<AlertEvent>> watchAlerts() => alerts.stream;
  @override
  Stream<FleetConnection> watchConnection() => connection.stream;

  @override
  Future<Rider> addRider(Rider rider) async => rider;
  @override
  Future<void> updateRider(Rider rider) async {}
  @override
  Future<void> setRiderActive(String riderId, bool active) async {}
  @override
  Future<String> linkAppAccount(String riderId, String username) async =>
      'rider@example.test';
  @override
  Future<void> unlinkAppAccount(String riderId) async {}
  @override
  Future<void> setRiderStatus(String riderId, RiderStatus status) async {}
  @override
  Future<void> transitionAlert(String alertId, AlertAction action) {
    final error = failWith;
    return error == null ? Future.value() : Future.error(error);
  }

  @override
  void dispose() {
    riders.close();
    telemetry.close();
    alerts.close();
    connection.close();
  }
}

class _SuperAdminAuth implements AdminAuth {
  final _changes = StreamController<AdminUser?>.broadcast();
  AdminUser? _current;

  static const _user = AdminUser(
    name: 'Ops Lead',
    email: 'op@tip.edu.ph',
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

final _rider = Rider(
  id: 'R-001',
  fullName: 'Ana Reyes',
  helmetId: 'NR-H1-001',
  phone: '+63 917 000 0000',
  status: RiderStatus.emergency,
  registeredAt: DateTime(2026, 9, 20),
);

final _openCrash = AlertEvent(
  id: 'A-101',
  riderId: 'R-001',
  riderName: 'Ana Reyes',
  type: AlertType.crash,
  lat: 14.5995,
  lng: 120.9842,
  address: 'EDSA, Quezon City',
  timestamp: DateTime(2026, 9, 21, 8, 30),
  status: AlertStatus.open,
);

/// The console never settles — the map's pulse animation runs for as long
/// as the dashboard is mounted — so page tests pump explicit durations.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Signs in, delivers one open crash, opens the Alerts tab and selects it.
Future<_ScriptedRepository> _openAlertsWithOneCrash(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _ScriptedRepository();
  final auth = _SuperAdminAuth();
  addTearDown(auth.dispose);
  await tester.pumpWidget(AdminApp(auth: auth, createRepository: () => repo));
  await tester.enterText(find.byType(TextFormField).first, 'op@tip.edu.ph');
  await tester.enterText(find.byType(TextFormField).last, 'pw');
  await tester.pump();
  await tester.tap(find.text('SIGN IN'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  repo.riders.add([_rider]);
  repo.telemetry.add(const []);
  repo.alerts.add([_openCrash]);
  repo.connection.add(FleetConnection.connected);
  await tester.pump();

  await tester.tap(find.text('Alerts').first);
  await _settle(tester);
  await tester.tap(find.byType(AlertFeedTile).first);
  await _settle(tester);
  expect(find.text('Acknowledge'), findsOneWidget);
  return repo;
}

void main() {
  group('Alerts page write failures', () {
    testWidgets('a FleetWriteException shows its own sentence', (tester) async {
      final repo = await _openAlertsWithOneCrash(tester);
      repo.failWith = const FleetWriteException(
        'Cannot reach Firestore — the change was not saved. Check the '
        'connection and try again.',
      );

      await tester.ensureVisible(find.text('Acknowledge'));
      await tester.tap(find.text('Acknowledge'));
      await _settle(tester);

      expect(find.textContaining('Cannot reach Firestore'), findsOneWidget);
    });

    testWidgets('anything else shows one fixed sentence, never the exception',
        (tester) async {
      final repo = await _openAlertsWithOneCrash(tester);
      repo.failWith = Exception('[cloud_firestore/permission-denied] '
          'Missing or insufficient permissions at alerts/A-101');

      await tester.ensureVisible(find.text('Acknowledge'));
      await tester.tap(find.text('Acknowledge'));
      await _settle(tester);

      expect(find.textContaining('The change was not saved.'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.textContaining('alerts/A-101'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });
  });
}
