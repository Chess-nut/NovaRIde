// The alert response lifecycle — the heart of the admin module.
//
// The research problem is emergency response time, so these tests assert on
// the state machine and its audit trail rather than on rendered pixels:
// legal transitions succeed, illegal ones are rejected loudly, history is
// appended in order, and a resolved incident releases its rider.

import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/state/mock_fleet_controller.dart';
import 'package:novaride/shared/models/models.dart';

/// A controller with its timers cancelled at teardown, so a test never leaks
/// the simulation into the next one.
MockFleetController _controller() {
  final fleet = MockFleetController();
  addTearDown(fleet.dispose);
  return fleet;
}

void main() {
  group('legal transitions', () {
    test('open → acknowledged → dispatched → resolved all succeed', () {
      final fleet = _controller();

      fleet.acknowledgeAlert('A-101', actor: 'Ops Admin');
      expect(fleet.alerts.firstWhere((a) => a.id == 'A-101').status,
          AlertStatus.acknowledged);

      fleet.dispatchAlert(
        'A-101',
        actor: 'Ops Admin',
        responder: ResponderType.medical,
      );
      expect(fleet.alerts.firstWhere((a) => a.id == 'A-101').status,
          AlertStatus.dispatched);

      fleet.resolveAlert('A-101', actor: 'Ops Admin');
      expect(fleet.alerts.firstWhere((a) => a.id == 'A-101').status,
          AlertStatus.resolved);
    });

    test('the enum knows its own successor', () {
      expect(AlertStatus.open.nextStatus, AlertStatus.acknowledged);
      expect(AlertStatus.acknowledged.nextStatus, AlertStatus.dispatched);
      expect(AlertStatus.dispatched.nextStatus, AlertStatus.resolved);
      expect(AlertStatus.resolved.nextStatus, isNull);

      expect(AlertStatus.open.canTransitionTo(AlertStatus.acknowledged), isTrue);
      expect(AlertStatus.open.canTransitionTo(AlertStatus.resolved), isFalse);
    });
  });

  group('illegal transitions', () {
    test('skipping a step throws and leaves the alert untouched', () {
      final fleet = _controller();

      expect(
        () => fleet.resolveAlert('A-101', actor: 'Ops'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => fleet.dispatchAlert(
          'A-101',
          actor: 'Ops',
          responder: ResponderType.police,
        ),
        throwsA(isA<StateError>()),
      );

      final alert = fleet.alerts.firstWhere((a) => a.id == 'A-101');
      expect(alert.status, AlertStatus.open);
      expect(alert.history, isEmpty);
    });

    test('repeating or reversing a step throws', () {
      final fleet = _controller();

      fleet.acknowledgeAlert('A-101', actor: 'Ops');
      expect(
        () => fleet.acknowledgeAlert('A-101', actor: 'Ops'),
        throwsA(isA<StateError>()),
      );

      fleet.dispatchAlert(
        'A-101',
        actor: 'Ops',
        responder: ResponderType.medical,
      );
      // Backwards to acknowledged is not a legal move.
      expect(
        () => fleet.acknowledgeAlert('A-101', actor: 'Ops'),
        throwsA(isA<StateError>()),
      );
    });

    test('a resolved alert accepts nothing further', () {
      final fleet = _controller();

      fleet.acknowledgeAlert('A-101', actor: 'Ops');
      fleet.dispatchAlert('A-101',
          actor: 'Ops', responder: ResponderType.medical);
      fleet.resolveAlert('A-101', actor: 'Ops');

      expect(
        () => fleet.resolveAlert('A-101', actor: 'Ops'),
        throwsA(isA<StateError>()),
      );
    });

    test('an unknown alert id throws with a descriptive message', () {
      final fleet = _controller();

      expect(
        () => fleet.acknowledgeAlert('A-DOES-NOT-EXIST', actor: 'Ops'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('A-DOES-NOT-EXIST'),
          ),
        ),
      );
    });

    test('a rejected transition does not notify listeners', () {
      final fleet = _controller();

      var notifications = 0;
      fleet.addListener(() => notifications++);

      expect(() => fleet.resolveAlert('A-101', actor: 'Ops'), throwsStateError);
      expect(notifications, 0, reason: 'rejected action triggered a rebuild');

      fleet.acknowledgeAlert('A-101', actor: 'Ops');
      expect(notifications, 1);
    });
  });

  group('audit trail', () {
    test('history is appended in order with actor, note and responder', () {
      final fleet = _controller();

      fleet.acknowledgeAlert('A-101', actor: 'Marisol Cruz');
      fleet.dispatchAlert(
        'A-101',
        actor: 'Marisol Cruz',
        responder: ResponderType.fireRescue,
        note: 'Trapped under the vehicle',
      );
      fleet.resolveAlert('A-101', actor: 'Ops Admin', note: 'Rider stable');

      final history = fleet.alerts.firstWhere((a) => a.id == 'A-101').history;

      expect(history.map((h) => h.toStatus).toList(), [
        AlertStatus.acknowledged,
        AlertStatus.dispatched,
        AlertStatus.resolved,
      ]);

      expect(history[0].actorName, 'Marisol Cruz');
      expect(history[0].responder, isNull);
      expect(history[0].note, isNull);

      expect(history[1].responder, ResponderType.fireRescue);
      expect(history[1].note, 'Trapped under the vehicle');

      expect(history[2].actorName, 'Ops Admin');
      expect(history[2].note, 'Rider stable');

      // Timestamps never go backwards.
      for (var i = 1; i < history.length; i++) {
        expect(history[i].at.isBefore(history[i - 1].at), isFalse);
      }
    });

    test('reachedAt reports when each stage was entered', () {
      final fleet = _controller();

      final alert = fleet.alerts.firstWhere((a) => a.id == 'A-101');
      expect(alert.reachedAt(AlertStatus.acknowledged), isNull);

      fleet.acknowledgeAlert('A-101', actor: 'Ops');

      final updated = fleet.alerts.firstWhere((a) => a.id == 'A-101');
      expect(updated.reachedAt(AlertStatus.acknowledged), isNotNull);
      expect(updated.reachedAt(AlertStatus.resolved), isNull);
    });
  });

  group('rider status on resolve', () {
    test('resolving the last active critical alert clears the emergency', () {
      final fleet = _controller();

      // R-003 is seeded in emergency with one open crash, A-101.
      expect(fleet.riderFor('R-003')!.status, RiderStatus.emergency);

      fleet.acknowledgeAlert('A-101', actor: 'Ops');
      fleet.dispatchAlert('A-101',
          actor: 'Ops', responder: ResponderType.medical);

      expect(
        fleet.riderFor('R-003')!.status,
        RiderStatus.emergency,
        reason: 'rider must stay red while responders are en route',
      );

      fleet.resolveAlert('A-101', actor: 'Ops');
      expect(fleet.riderFor('R-003')!.status, RiderStatus.idle);
    });

    test('a non-critical alert does not disturb the rider status', () {
      final fleet = _controller();

      // A-099 is a low-battery alert for R-010, who is offline.
      final before = fleet.riderFor('R-010')!.status;

      fleet.acknowledgeAlert('A-099', actor: 'Ops');
      fleet.dispatchAlert('A-099',
          actor: 'Ops', responder: ResponderType.barangay);
      fleet.resolveAlert('A-099', actor: 'Ops');

      expect(fleet.riderFor('R-010')!.status, before);
    });

    test('openCriticalCount drops as criticals are closed', () {
      final fleet = _controller();

      final before = fleet.openCriticalCount;
      expect(before, greaterThan(0));

      fleet.acknowledgeAlert('A-101', actor: 'Ops');
      expect(fleet.openCriticalCount, before,
          reason: 'acknowledged is still active');

      fleet.dispatchAlert('A-101',
          actor: 'Ops', responder: ResponderType.medical);
      expect(fleet.openCriticalCount, before,
          reason: 'dispatched is still active');

      fleet.resolveAlert('A-101', actor: 'Ops');
      expect(fleet.openCriticalCount, before - 1);
    });
  });

  group('derived response metrics', () {
    test('averages are null until something has been acted on', () {
      final fleet = _controller();

      expect(fleet.averageAcknowledgeTime, isNull);
      expect(fleet.averageResolveTime, isNull);

      fleet.acknowledgeAlert('A-101', actor: 'Ops');
      expect(fleet.averageAcknowledgeTime, isNotNull);
      expect(fleet.averageResolveTime, isNull);

      fleet.dispatchAlert('A-101',
          actor: 'Ops', responder: ResponderType.medical);
      fleet.resolveAlert('A-101', actor: 'Ops');
      expect(fleet.averageResolveTime, isNotNull);
    });

    test('acknowledge time is measured from when the alert fired', () {
      final fleet = _controller();

      // A-101 is seeded two minutes old, so acknowledging it now records
      // roughly two minutes — not roughly zero.
      fleet.acknowledgeAlert('A-101', actor: 'Ops');

      final average = fleet.averageAcknowledgeTime!;
      expect(average.inSeconds, greaterThanOrEqualTo(110));
      expect(average.inSeconds, lessThanOrEqualTo(130));
    });
  });

  group('automatic stand-down', () {
    test('never clears a rider whose critical alert is still active', () {
      final fleet = _controller();

      fleet.acknowledgeAlert('A-101', actor: 'Ops');
      expect(fleet.riderFor('R-003')!.status, RiderStatus.emergency);

      // Drive the simulation hard enough to trip the three-emergency guard
      // many times over.
      for (var i = 0; i < 60; i++) {
        fleet.debugEmitAlert();
      }

      final r3 = fleet.riderFor('R-003')!;
      final stillActive = fleet.alerts.any(
        (a) => a.riderId == 'R-003' && a.type.isCritical && a.status.isActive,
      );

      // While A-101 is on the board and unresolved, R-003 stays red. Once the
      // 40-alert cap ages it off, the rider becomes eligible again — both are
      // correct, so assert the invariant rather than a fixed status.
      if (stillActive) {
        expect(r3.status, RiderStatus.emergency,
            reason: 'operator-owned alert was overwritten by stand-down');
      }
    });
  });
}
