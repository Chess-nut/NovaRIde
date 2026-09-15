// Controller invariants: the derived getters every dashboard panel reads
// must stay consistent with the underlying lists after mutations, and the
// alert board must respect its cap however long the simulation runs.

import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/data/mock_fleet_repository.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/shared/models/models.dart';

/// A controller over a fresh simulation. Disposing the controller cancels
/// the repository's timers, so a test never leaks the simulation into the
/// next one. The repository is kept so tests can drive the simulation by hand.
late MockFleetRepository _repo;

FleetController _controller() {
  _repo = MockFleetRepository();
  final fleet = FleetController(_repo);
  addTearDown(fleet.dispose);
  return fleet;
}

int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);

void main() {
  group('statusCounts', () {
    test('covers every rider exactly once and keeps all buckets present', () {
      final fleet = _controller();

      final counts = fleet.statusCounts;
      expect(counts.keys.toSet(), RiderStatus.values.toSet(),
          reason: 'donut legend needs a stable bucket order, even at zero');
      expect(_sum(counts.values), fleet.riders.length);
    });

    test('stays consistent after adding, deactivating and resolving', () {
      final fleet = _controller();

      fleet.addRider(Rider(
        id: 'R-011',
        fullName: 'Bagong Sakay',
        helmetId: 'NR-H1-011',
        phone: '+63 917 123 4567',
        status: RiderStatus.riding,
      ));
      expect(_sum(fleet.statusCounts.values), fleet.riders.length);

      fleet.setRiderActive('R-011', false);
      expect(_sum(fleet.statusCounts.values), fleet.riders.length);
      expect(fleet.statusCounts[RiderStatus.offline], greaterThan(0));

      // Resolving a crash moves R-003 emergency → idle; the total is unchanged.
      fleet.acknowledgeAlert('A-101', actor: 'Ops');
      fleet.dispatchAlert('A-101',
          actor: 'Ops', responder: ResponderType.medical);
      fleet.resolveAlert('A-101', actor: 'Ops');
      expect(_sum(fleet.statusCounts.values), fleet.riders.length);
    });
  });

  group('alertsByArea', () {
    test('every alert lands in exactly one district', () {
      final fleet = _controller();

      expect(_sum(fleet.alertsByArea.values), fleet.alerts.length);
      expect(fleet.alertsByArea.keys.length, kFleetDistricts.length);
    });

    test('stays balanced as the simulation spawns alerts', () {
      final fleet = _controller();

      for (var i = 0; i < 25; i++) {
        _repo.debugEmitAlert();
      }
      expect(_sum(fleet.alertsByArea.values), fleet.alerts.length);
    });

    test('nearestDistrict picks the closest centre', () {
      // Exactly on the Makati centroid.
      final makati =
          FleetController.nearestDistrict(14.5547, 121.0244);
      expect(makati.name, 'Makati');

      final fairview =
          FleetController.nearestDistrict(14.7297, 121.0644);
      expect(fairview.name, 'Fairview');
    });
  });

  group('alertsByPriority', () {
    test('buckets every alert and demotes resolved ones to none', () {
      final fleet = _controller();

      expect(_sum(fleet.alertsByPriority.values), fleet.alerts.length);

      final noneBefore = fleet.alertsByPriority[AlertPriority.none]!;
      final criticalBefore = fleet.alertsByPriority[AlertPriority.critical]!;

      // A-101 is an open crash — critical until it is closed.
      expect(criticalBefore, greaterThan(0));

      fleet.acknowledgeAlert('A-101', actor: 'Ops');
      fleet.dispatchAlert('A-101',
          actor: 'Ops', responder: ResponderType.medical);
      fleet.resolveAlert('A-101', actor: 'Ops');

      expect(fleet.alertsByPriority[AlertPriority.critical], criticalBefore - 1);
      expect(fleet.alertsByPriority[AlertPriority.none], noneBefore + 1);
      expect(_sum(fleet.alertsByPriority.values), fleet.alerts.length);
    });

    test('priorityOf ranks life-critical types first', () {
      AlertEvent alert(AlertType type, AlertStatus status) => AlertEvent(
            id: 'X',
            riderId: 'R-001',
            riderName: 'Test',
            type: type,
            lat: 14.6,
            lng: 121.0,
            address: 'somewhere',
            timestamp: DateTime.now(),
            status: status,
          );

      expect(
        FleetController.priorityOf(alert(AlertType.crash, AlertStatus.open)),
        AlertPriority.critical,
      );
      expect(
        FleetController.priorityOf(alert(AlertType.sos, AlertStatus.open)),
        AlertPriority.high,
      );
      expect(
        FleetController.priorityOf(
            alert(AlertType.lowBattery, AlertStatus.open)),
        AlertPriority.low,
      );
      // Resolved stops competing for attention whatever the type.
      expect(
        FleetController.priorityOf(
            alert(AlertType.crash, AlertStatus.resolved)),
        AlertPriority.none,
      );
    });
  });

  group('alertsByType', () {
    test('totals match the alert list before and after spawning', () {
      final fleet = _controller();

      expect(_sum(fleet.alertsByType.values), fleet.alerts.length);
      expect(fleet.alertsByType.keys.toSet(), AlertType.values.toSet());

      for (var i = 0; i < 15; i++) {
        _repo.debugEmitAlert();
      }
      expect(_sum(fleet.alertsByType.values), fleet.alerts.length);
    });
  });

  group('alert board cap', () {
    test('never exceeds the 40-alert cap and keeps the newest', () {
      final fleet = _controller();

      for (var i = 0; i < 120; i++) {
        _repo.debugEmitAlert();
      }

      expect(fleet.alerts.length, lessThanOrEqualTo(40));
      expect(fleet.alerts.length, 40, reason: 'board should be saturated');

      // Newest-first ordering survives the trimming.
      for (var i = 1; i < fleet.alerts.length; i++) {
        expect(
          fleet.alerts[i].timestamp
              .isAfter(fleet.alerts[i - 1].timestamp),
          isFalse,
          reason: 'alerts are not newest-first at index $i',
        );
      }

      // The oldest seeded alerts have been aged off.
      expect(fleet.alerts.any((a) => a.id == 'A-097'), isFalse);

      // Derived getters remain consistent at the cap.
      expect(_sum(fleet.alertsByType.values), fleet.alerts.length);
      expect(_sum(fleet.alertsByArea.values), fleet.alerts.length);
      expect(_sum(fleet.alertsByPriority.values), fleet.alerts.length);
    });

    test('alert IDs stay unique across the run', () {
      final fleet = _controller();

      for (var i = 0; i < 60; i++) {
        _repo.debugEmitAlert();
      }

      final ids = fleet.alerts.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('selection and trails', () {
    test('selectRider notifies only on an actual change', () {
      final fleet = _controller();

      var notifications = 0;
      fleet.addListener(() => notifications++);

      fleet.selectRider('R-002');
      fleet.selectRider('R-002');
      expect(fleet.selectedRiderId, 'R-002');
      expect(notifications, 1);

      fleet.selectRider(null);
      expect(fleet.selectedRiderId, isNull);
      expect(notifications, 2);
    });

    test('trails start seeded and stay within the cap', () {
      final fleet = _controller();

      for (final rider in fleet.riders) {
        final trail = fleet.trailFor(rider.id);
        expect(trail, isNotEmpty, reason: '${rider.id} has no seed fix');
        expect(trail.length, lessThanOrEqualTo(20));
      }

      expect(fleet.trailFor('nobody'), isEmpty);
    });

    test('a new rider is immediately plottable', () {
      final fleet = _controller();

      fleet.addRider(Rider(
        id: 'R-011',
        fullName: 'Bagong Sakay',
        helmetId: 'NR-H1-011',
        phone: '+63 917 123 4567',
        status: RiderStatus.riding,
      ));

      expect(fleet.telemetryFor('R-011'), isNotNull);
      expect(fleet.trailFor('R-011'), hasLength(1));
    });
  });

  group('roster mutations', () {
    test('addRider rejects duplicate ids and helmet serials', () {
      final fleet = _controller();

      expect(
        () => fleet.addRider(Rider(
          id: 'R-001',
          fullName: 'Duplicate Id',
          helmetId: 'NR-H1-099',
          phone: '+63 917 123 4567',
          status: RiderStatus.idle,
        )),
        throwsA(isA<StateError>()),
      );

      expect(
        () => fleet.addRider(Rider(
          id: 'R-099',
          fullName: 'Duplicate Helmet',
          helmetId: 'NR-H1-001',
          phone: '+63 917 123 4567',
          status: RiderStatus.idle,
        )),
        throwsA(isA<StateError>()),
      );
    });

    test('updateRider refuses to steal another rider\'s helmet', () {
      final fleet = _controller();

      final rider = fleet.riderFor('R-002')!;
      expect(
        () => fleet.updateRider(rider.copyWith(helmetId: 'NR-H1-001')),
        throwsA(isA<StateError>()),
      );

      // Keeping its own helmet is fine.
      fleet.updateRider(rider.copyWith(fullName: 'Maricel B. Bautista'));
      expect(fleet.riderFor('R-002')!.fullName, 'Maricel B. Bautista');
    });

    test('deactivation preserves the rider and their alert history', () {
      final fleet = _controller();

      final alertsBefore =
          fleet.alerts.where((a) => a.riderId == 'R-003').length;

      fleet.setRiderActive('R-003', false);

      expect(fleet.riderFor('R-003'), isNotNull, reason: 'must not hard-delete');
      expect(fleet.riderFor('R-003')!.isActive, isFalse);
      expect(fleet.riderFor('R-003')!.status, RiderStatus.offline);
      expect(fleet.alerts.where((a) => a.riderId == 'R-003').length,
          alertsBefore);

      fleet.setRiderActive('R-003', true);
      expect(fleet.riderFor('R-003')!.isActive, isTrue);
      expect(fleet.riderFor('R-003')!.status, RiderStatus.idle);
    });

    test('an unknown rider id throws rather than silently doing nothing', () {
      final fleet = _controller();

      expect(() => fleet.setRiderActive('R-999', false),
          throwsA(isA<StateError>()));
      expect(
        () => fleet.updateRider(Rider(
          id: 'R-999',
          fullName: 'Ghost',
          helmetId: 'NR-H1-999',
          phone: '+63 917 123 4567',
          status: RiderStatus.idle,
        )),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('exposed collections', () {
    test('are unmodifiable, so panels cannot mutate fleet state', () {
      final fleet = _controller();

      expect(() => fleet.riders.clear(), throwsUnsupportedError);
      expect(() => fleet.alerts.clear(), throwsUnsupportedError);
      expect(() => fleet.telemetry.clear(), throwsUnsupportedError);
      expect(() => fleet.trailFor('R-001').clear(), throwsUnsupportedError);
    });
  });
}
