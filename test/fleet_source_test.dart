// The data-source seam: the top bar must say which source the console is on,
// the connection pill must follow the repository's own report, and a
// repository whose streams arrive asynchronously (as Firestore's do) must
// still feed the controller correctly.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/data/mock_fleet_repository.dart';
import 'package:novaride/admin/mock/mock_data.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/main_admin.dart';
import 'package:novaride/shared/models/models.dart';

/// Stands in for Firestore: async broadcast streams, nothing until told.
class _CloudLikeRepository implements FleetRepository {
  final riders = StreamController<List<Rider>>.broadcast();
  final telemetry = StreamController<List<HelmetTelemetry>>.broadcast();
  final alerts = StreamController<List<AlertEvent>>.broadcast();
  final connection = StreamController<FleetConnection>.broadcast();

  final writes = <String>[];

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
  Future<void> addRider(Rider rider) async => writes.add('add ${rider.id}');
  @override
  Future<void> updateRider(Rider rider) async =>
      writes.add('update ${rider.id}');
  @override
  Future<void> setRiderStatus(String riderId, RiderStatus status) async =>
      writes.add('status $riderId ${status.name}');
  @override
  Future<void> transitionAlert(String alertId, AlertAction action) async =>
      writes.add('transition $alertId ${action.toStatus.name}');

  @override
  void dispose() {
    riders.close();
    telemetry.close();
    alerts.close();
    connection.close();
  }
}

Future<void> _useDesktopSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
      find.byType(TextFormField).first, 'admin@novaride.ph');
  await tester.enterText(find.byType(TextFormField).last, 'admin123');
  // The button enables on the frame after both fields are filled.
  await tester.pump();
  await tester.tap(find.text('SIGN IN'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  group('top bar source chip', () {
    testWidgets('a bare AdminApp runs on the simulation and says so',
        (tester) async {
      await _useDesktopSurface(tester);
      await tester.pumpWidget(const AdminApp());
      await _signIn(tester);

      expect(find.text('SIMULATION'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('FIRESTORE'), findsNothing);

      await _tearDownTree(tester);
    });

    testWidgets('an injected cloud repository shows FIRESTORE and follows '
        'its connection report', (tester) async {
      await _useDesktopSurface(tester);
      final repo = _CloudLikeRepository();

      await tester.pumpWidget(AdminApp(createRepository: () => repo));
      await _signIn(tester);

      expect(find.text('FIRESTORE'), findsOneWidget);
      expect(find.text('CONNECTING'), findsOneWidget,
          reason: 'nothing has arrived yet');

      repo.connection.add(FleetConnection.connected);
      await tester.pump();
      expect(find.text('LIVE'), findsOneWidget);

      repo.connection.add(const FleetConnection(
        FleetConnectionState.disconnected,
        'Showing cached data',
      ));
      await tester.pump();
      expect(find.text('OFFLINE'), findsOneWidget);

      await _tearDownTree(tester);
    });
  });

  group('FleetController over an async source', () {
    test('starts empty, loads as streams arrive, and writes go to the repo',
        () async {
      final repo = _CloudLikeRepository();
      final fleet = FleetController(repo);
      addTearDown(fleet.dispose);

      expect(fleet.isLoaded, isFalse);
      expect(fleet.riders, isEmpty);
      expect(fleet.source, FleetSource.firestore);

      repo.riders.add(MockData.riders);
      repo.telemetry.add(MockData.telemetry);
      repo.alerts.add(MockData.alerts);
      await Future<void>.delayed(Duration.zero);

      expect(fleet.isLoaded, isTrue);
      expect(fleet.riders.length, MockData.riders.length);
      expect(fleet.trailFor('R-001'), hasLength(1),
          reason: 'first telemetry seeds the breadcrumb');

      // Rule checks still run locally and synchronously.
      expect(() => fleet.resolveAlert('A-101', actor: 'Ops'), throwsStateError);
      expect(repo.writes, isEmpty);

      await fleet.acknowledgeAlert('A-101', actor: 'Ops');
      expect(repo.writes, ['transition A-101 acknowledged']);

      // Nothing changes locally until the source echoes the write back.
      expect(fleet.alerts.firstWhere((a) => a.id == 'A-101').status,
          AlertStatus.open);
    });

    test('resolving the last critical alert also releases the rider',
        () async {
      final repo = _CloudLikeRepository();
      final fleet = FleetController(repo);
      addTearDown(fleet.dispose);

      repo.riders.add(MockData.riders);
      repo.telemetry.add(MockData.telemetry);
      // A-101 is R-003's open crash; pretend it has been dispatched already.
      repo.alerts.add([
        for (final a in MockData.alerts)
          a.id == 'A-101' ? a.copyWith(status: AlertStatus.dispatched) : a,
      ]);
      await Future<void>.delayed(Duration.zero);

      await fleet.resolveAlert('A-101', actor: 'Ops');
      expect(repo.writes, [
        'transition A-101 resolved',
        'status R-003 idle',
      ]);
    });

    test('the mock repository satisfies the same contract synchronously', () {
      final repo = MockFleetRepository(simulate: false);
      final fleet = FleetController(repo);
      addTearDown(fleet.dispose);

      expect(fleet.isLoaded, isTrue);
      expect(fleet.source, FleetSource.simulation);
      expect(fleet.connection.isConnected, isTrue);
    });
  });
}
