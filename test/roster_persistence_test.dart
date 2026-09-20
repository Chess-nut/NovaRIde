// Roster writes against a store that answers late, refuses, moves the rider
// id, or never answers — the Firestore cases the simulation cannot produce.
// The controller must show the change at once, keep it while the store is
// thinking, and withdraw it cleanly on failure; the page must say what
// happened in a sentence, never an exception. Nothing here touches Firebase.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/data/admin_auth.dart';
import 'package:novaride/admin/data/firestore_fleet_repository.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/state/admin_session.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/main_admin.dart';
import 'package:novaride/shared/models/models.dart';

/// A cloud-shaped store under test control: streams that deliver only when
/// told, and writes that resolve (or fail) only when told.
class _ScriptedRepository implements FleetRepository {
  final riders = StreamController<List<Rider>>.broadcast();
  final telemetry = StreamController<List<HelmetTelemetry>>.broadcast();
  final alerts = StreamController<List<AlertEvent>>.broadcast();
  final connection = StreamController<FleetConnection>.broadcast();

  /// Every write, in order, as the repository saw it.
  final log = <String>[];

  /// The next write completes this instead of resolving on its own. Null
  /// means "resolve immediately".
  Completer<Rider>? pending;

  /// What the next write throws instead of succeeding.
  Object? failWith;

  /// What [addRider] resolves to; null means the rider as given.
  Rider Function(Rider)? savedAs;

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

  Future<Rider> _answer(String entry, Rider rider) {
    log.add(entry);
    if (failWith != null) return Future.error(failWith!);
    return pending?.future ?? Future.value(rider);
  }

  @override
  Future<Rider> addRider(Rider rider) =>
      _answer('add ${rider.id}', savedAs?.call(rider) ?? rider);
  @override
  Future<void> updateRider(Rider rider) => _answer('update ${rider.id}', rider);
  @override
  Future<void> setRiderActive(String riderId, bool active) =>
      _answer('active $riderId $active', _placeholder);
  @override
  Future<void> setRiderStatus(String riderId, RiderStatus status) async =>
      log.add('status $riderId ${status.name}');
  @override
  Future<void> transitionAlert(String alertId, AlertAction action) async =>
      log.add('transition $alertId');

  @override
  void dispose() {
    riders.close();
    telemetry.close();
    alerts.close();
    connection.close();
  }
}

final _placeholder = Rider(
  id: '-',
  fullName: '-',
  helmetId: '-',
  phone: '-',
  status: RiderStatus.idle,
);

Rider _rider(String id, {String helmet = 'NR-H1-001', String name = 'Ana'}) =>
    Rider(
      id: id,
      fullName: name,
      helmetId: helmet,
      phone: '+63 917 000 0000',
      status: RiderStatus.idle,
      registeredAt: DateTime(2026, 9, 20),
    );

/// A controller over a scripted store that has already delivered [initial].
(FleetController, _ScriptedRepository) _fleet([List<Rider> initial = const []]) {
  final repo = _ScriptedRepository();
  final fleet = FleetController(repo);
  addTearDown(fleet.dispose);
  repo.riders.add(initial);
  return (fleet, repo);
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

/// The console never settles — the map's pulse animation runs for as long
/// as the dashboard is mounted — so page tests pump explicit durations.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('optimistic roster writes', () {
    test('a new rider is on the roster before the store answers, and stays '
        'there once it does', () async {
      final (fleet, repo) = _fleet();
      await _flush();
      repo.pending = Completer<Rider>();

      final future = fleet.addRider(_rider('R-001'));
      expect(fleet.riders.map((r) => r.id), ['R-001'],
          reason: 'shown at once');
      expect(repo.log, ['add R-001']);

      // The store echoes the write through its stream, then answers.
      repo.riders.add([_rider('R-001')]);
      await _flush();
      repo.pending!.complete(_rider('R-001'));
      await future;

      expect(fleet.riders.map((r) => r.id), ['R-001']);
      expect(fleet.riders.length, 1, reason: 'never shown twice');
    });

    test('a refused add is withdrawn and the message reaches the caller',
        () async {
      final (fleet, repo) = _fleet();
      await _flush();
      repo.failWith = const FleetWriteException('Firestore refused it.');

      await expectLater(
        fleet.addRider(_rider('R-001')),
        throwsA(isA<FleetWriteException>()
            .having((e) => e.message, 'message', 'Firestore refused it.')),
      );
      expect(fleet.riders, isEmpty, reason: 'no ghost rider');
    });

    // A widget test only for its clock: the body runs on fake time, so the
    // deadline can be reached with pump() instead of waiting twenty seconds.
    testWidgets('a write that never answers is rolled back after the deadline',
        (tester) async {
      final repo = _ScriptedRepository();
      final fleet = FleetController(repo);
      addTearDown(fleet.dispose);
      repo.riders.add(const []);
      await tester.pump();
      repo.pending = Completer<Rider>(); // never completed

      Object? error;
      final done = fleet.addRider(_rider('R-001')).catchError((Object e) {
        error = e;
        return _placeholder;
      });
      await tester.pump();
      expect(fleet.riders.length, 1, reason: 'optimistic while waiting');

      await tester.pump(FleetController.writeTimeout - const Duration(seconds: 1));
      expect(fleet.riders.length, 1, reason: 'still waiting');

      await tester.pump(const Duration(seconds: 2));
      await done;
      expect(fleet.riders, isEmpty, reason: 'withdrawn at the deadline');
      expect(error, isA<FleetWriteException>());
      expect((error as FleetWriteException).message, contains('20 seconds'));
    });

    test('an add whose suggested id was taken follows the id the store '
        'assigned', () async {
      final (fleet, repo) = _fleet([_rider('R-010', helmet: 'NR-H1-010')]);
      await _flush();
      repo.savedAs = (r) => r.copyWith(id: 'R-012');

      final saved = await fleet.addRider(_rider('R-011', helmet: 'NR-H1-011'));
      expect(saved.id, 'R-012');
      expect(fleet.riders.map((r) => r.id), ['R-010', 'R-012'],
          reason: 'the suggested id is gone, the saved one is shown');

      // The store's snapshot arrives; the overlay steps aside without a flash.
      repo.riders.add([
        _rider('R-010', helmet: 'NR-H1-010'),
        _rider('R-012', helmet: 'NR-H1-011'),
      ]);
      await _flush();
      expect(fleet.riders.map((r) => r.id), ['R-010', 'R-012']);
    });

    test('a snapshot that predates the write does not un-show the rider',
        () async {
      final (fleet, repo) = _fleet([_rider('R-001')]);
      await _flush();
      repo.pending = Completer<Rider>();

      final future = fleet.addRider(_rider('R-002', helmet: 'NR-H1-002'));
      // An unrelated change lands first — somebody else's rider went idle.
      repo.riders.add([_rider('R-001', name: 'Ana Renamed')]);
      await _flush();
      expect(fleet.riders.map((r) => r.id), ['R-001', 'R-002'],
          reason: 'pending add survives an older snapshot');
      expect(fleet.riderFor('R-001')!.fullName, 'Ana Renamed',
          reason: 'and the snapshot itself is applied');

      repo.pending!.complete(_rider('R-002', helmet: 'NR-H1-002'));
      await future;
      expect(fleet.riders.map((r) => r.id), ['R-001', 'R-002']);
    });

    test('a refused edit restores the previous values', () async {
      final (fleet, repo) = _fleet([_rider('R-001')]);
      await _flush();
      repo.pending = Completer<Rider>();

      final future =
          fleet.updateRider(_rider('R-001', name: 'Ana Edited'));
      expect(fleet.riderFor('R-001')!.fullName, 'Ana Edited',
          reason: 'shown at once');

      repo.pending!.completeError(
          const FleetWriteException('Only a Super Admin may edit.'));
      await expectLater(future, throwsA(isA<FleetWriteException>()));
      expect(fleet.riderFor('R-001')!.fullName, 'Ana',
          reason: 'rolled back to what the store has');
    });

    test('deactivation is a narrow write and shows at once', () async {
      final (fleet, repo) = _fleet([_rider('R-001')]);
      await _flush();

      final future = fleet.setRiderActive('R-001', false);
      expect(fleet.riderFor('R-001')!.isActive, isFalse);
      expect(fleet.riderFor('R-001')!.status, RiderStatus.offline);
      await future;
      expect(repo.log, ['active R-001 false'],
          reason: 'isActive and status only — never the whole record');
    });

    test('a failure cannot withdraw a newer write to the same rider',
        () async {
      final (fleet, repo) = _fleet([_rider('R-001')]);
      await _flush();

      repo.pending = Completer<Rider>();
      final first = fleet.updateRider(_rider('R-001', name: 'First'));
      final firstCompleter = repo.pending!;

      repo.pending = Completer<Rider>();
      final second = fleet.updateRider(_rider('R-001', name: 'Second'));
      expect(fleet.riderFor('R-001')!.fullName, 'Second');

      firstCompleter.completeError(const FleetWriteException('nope'));
      await expectLater(first, throwsA(isA<FleetWriteException>()));
      expect(fleet.riderFor('R-001')!.fullName, 'Second',
          reason: 'the newer write still owns the row');

      repo.pending!.complete(_rider('R-001', name: 'Second'));
      await second;
    });
  });

  group('messageForWriteCode', () {
    test('explains every code the roster can hit and never leaks one', () {
      for (final code in [
        'permission-denied',
        'unavailable',
        'aborted',
        'not-found',
        'failed-precondition',
        'unauthenticated',
        'some-future-code',
      ]) {
        final message = messageForWriteCode(code);
        expect(message, isNot(contains(code)), reason: code);
        expect(message, isNot(contains('[')), reason: code);
        expect(message, endsWith('.'), reason: code);
      }
      expect(messageForWriteCode('permission-denied'), contains('Super Admin'));
      expect(messageForWriteCode('unavailable'), contains('not saved'));
    });
  });

  group('User Management page', () {
    testWidgets('a refused write shows a dismissable sentence and the rider '
        'leaves the roster', (tester) async {
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
      repo.riders.add(const []);
      repo.telemetry.add(const []);
      repo.alerts.add(const []);
      repo.connection.add(FleetConnection.connected);
      await tester.pump();

      await tester.tap(find.text('User Management').first);
      await tester.pump();
      await tester.tap(find.text('Add Rider'));
      await _settle(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Renato Villanueva');
      await tester.enterText(fields.at(2), '0917 402 8813');
      repo.pending = Completer<Rider>();
      await tester.tap(find.text('Add rider'));
      await _settle(tester);

      expect(find.text('Renato Villanueva'), findsOneWidget,
          reason: 'on the roster before the store answers');
      expect(repo.log, ['add R-001']);

      repo.pending!.completeError(const FleetWriteException(
          'Firestore refused the change. Only a Super Admin may edit the '
          'roster, and the security rules must be deployed.'));
      await _settle(tester);

      expect(find.text('Renato Villanueva'), findsNothing,
          reason: 'withdrawn — no ghost rider');
      expect(find.textContaining('Firestore refused the change'),
          findsOneWidget);
      expect(find.text('DISMISS'), findsOneWidget, reason: 'stays until read');
      expect(find.textContaining('Exception'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('a duplicate helmet is refused inline, before any write',
        (tester) async {
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
      repo.riders.add([_rider('R-001', helmet: 'NR-H1-001')]);
      repo.telemetry.add(const []);
      repo.alerts.add(const []);
      repo.connection.add(FleetConnection.connected);
      await tester.pump();

      await tester.tap(find.text('User Management').first);
      await tester.pump();
      await tester.tap(find.text('Add Rider'));
      await _settle(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Second Rider');
      await tester.enterText(fields.at(1), 'NR-H1-001');
      await tester.enterText(fields.at(2), '0917 402 8813');
      await tester.tap(find.text('Add rider'));
      await _settle(tester);

      expect(find.text('Helmet NR-H1-001 is already assigned'), findsOneWidget);
      expect(repo.log, isEmpty, reason: 'no document written');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
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
