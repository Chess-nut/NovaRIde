// A RiderAlertRepository that never touches Firestore, driven by the test.
//
// The countdown gate wraps every screen, so every test that pumps the app
// signed in builds this provider. Without the fake it would construct the
// Firestore one and die on "no Firebase app".

import 'dart:async';

import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/features/rider/domain/entities/rider_alert.dart';
import 'package:novaride/features/rider/domain/repositories/rider_alert_repository.dart';

class FakeRiderAlertRepository implements RiderAlertRepository {
  FakeRiderAlertRepository({LinkedRider? rider, List<RiderAlert> alerts = const []})
      : _rider = rider,
        _alerts = alerts;

  LinkedRider? _rider;
  List<RiderAlert> _alerts;
  final _riderCtrl = StreamController<LinkedRider?>.broadcast();
  final _alertsCtrl = StreamController<List<RiderAlert>>.broadcast();

  /// Every write, in order.
  final List<String> calls = [];

  /// What the next cancel throws, as the rules would refuse it.
  Failure? failCancelWith;

  void emitRider(LinkedRider? rider) => _riderCtrl.add(_rider = rider);
  void emitAlerts(List<RiderAlert> alerts) => _alertsCtrl.add(_alerts = alerts);

  @override
  Stream<LinkedRider?> watchLinkedRider(String uid) async* {
    yield _rider;
    yield* _riderCtrl.stream;
  }

  @override
  Stream<List<RiderAlert>> watchAlerts(String riderId) async* {
    yield _alerts;
    yield* _alertsCtrl.stream;
  }

  @override
  Future<void> cancelPendingCrash({
    required String alertId,
    required String riderId,
    required bool standDown,
  }) async {
    calls.add('cancel $alertId $riderId${standDown ? ' +standDown' : ''}');
    final failure = failCancelWith;
    if (failure != null) throw failure;
  }

  @override
  Future<void> standDown({required String riderId, required String alertId}) async {
    calls.add('standDown $riderId $alertId');
  }
}
