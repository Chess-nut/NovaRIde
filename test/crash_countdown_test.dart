// The false-positive countdown, as the rider sees it.
//
// The gate's ticker re-arms every 250 ms until the countdown ends on the
// real clock, so these tests pump frames by hand rather than settling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/features/rider/domain/entities/rider_alert.dart';

import 'support/fake_rider_alert_repository.dart';
import 'support/mobile_app.dart';

const _rider = LinkedRider(
  riderId: 'R-001', fullName: 'Rider One', helmetId: 'NR-H1-001', status: 'emergency',
);

RiderAlert _crash({
  String id = 'A-1',
  RiderAlertStatus status = RiderAlertStatus.pending,
  Duration age = const Duration(seconds: 2),
  String type = 'crash',
}) =>
    RiderAlert(
      id: id,
      riderId: 'R-001',
      type: type,
      severity: 'high',
      status: status,
      timestamp: DateTime.now().subtract(age),
    );

Future<FakeRiderAlertRepository> _pump(
  WidgetTester tester, {
  LinkedRider? rider = _rider,
  List<RiderAlert> alerts = const [],
}) async {
  final repo = FakeRiderAlertRepository(rider: rider, alerts: alerts);
  await pumpMobileApp(
    tester,
    auth: AuthState.signedIn(profileFor(UserRole.rider)),
    riderAlerts: repo,
    settle: false,
  );
  await _frames(tester);
  return repo;
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final _cancelButton = find.text('I\'m OK — cancel alert');

void main() {
  silenceAppLogger();

  testWidgets('a pending crash covers the screen with a countdown', (tester) async {
    await _pump(tester, alerts: [_crash()]);

    expect(find.text('Crash detected'), findsOneWidget);
    final seconds = tester.widget<Text>(find.byKey(const ValueKey('countdown-seconds')));
    expect(int.parse(seconds.data!), inInclusiveRange(12, 15));
    expect(_cancelButton, findsOneWidget);
  });

  testWidgets('"I\'m OK" cancels it and stands the rider down in one batch',
      (tester) async {
    final repo = await _pump(tester, alerts: [_crash()]);

    await tester.tap(_cancelButton);
    await _frames(tester);

    expect(repo.calls, ['cancel A-1 R-001 +standDown']);
    expect(find.text('Alert cancelled'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await _frames(tester);
    expect(find.text('Alert cancelled'), findsNothing);
    expect(find.text('Crash detected'), findsNothing,
        reason: 'a dismissed alert does not come back');
  });

  testWidgets('an alert whose countdown has passed is not offered', (tester) async {
    await _pump(tester, alerts: [_crash(age: const Duration(seconds: 30))]);
    expect(find.text('Crash detected'), findsNothing);
  });

  testWidgets('nothing but a pending crash is offered', (tester) async {
    await _pump(tester, alerts: [
      _crash(id: 'open', status: RiderAlertStatus.open),
      _crash(id: 'sos', type: 'sos'),
    ]);
    expect(find.text('Crash detected'), findsNothing);
  });

  testWidgets('an unlinked rider sees nothing', (tester) async {
    await _pump(tester, rider: null, alerts: [_crash()]);
    expect(find.text('Crash detected'), findsNothing);
  });

  testWidgets('when the countdown runs out, the rider is told help is coming',
      (tester) async {
    await _pump(tester, alerts: [
      _crash(age: const Duration(seconds: 15) - const Duration(milliseconds: 600)),
    ]);
    expect(find.text('Crash detected'), findsOneWidget);

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('The dispatcher has been alerted'), findsOneWidget);
    expect(_cancelButton, findsNothing);
  });

  testWidgets('a refused cancel says so: the dispatcher has the alert',
      (tester) async {
    final repo = FakeRiderAlertRepository(rider: _rider, alerts: [_crash()])
      ..failCancelWith = const PermissionFailure('denied');
    await pumpMobileApp(
      tester,
      auth: AuthState.signedIn(profileFor(UserRole.rider)),
      riderAlerts: repo,
      settle: false,
    );
    await _frames(tester);

    await tester.tap(_cancelButton);
    await _frames(tester);

    expect(find.text('The alert could not be cancelled'), findsOneWidget);
  });

  testWidgets('a dispatcher acknowledging first ends the countdown', (tester) async {
    final repo = await _pump(tester, alerts: [_crash()]);

    repo.emitAlerts([_crash(status: RiderAlertStatus.acknowledged)]);
    await _frames(tester);

    expect(find.text('A dispatcher is responding'), findsOneWidget);
    expect(_cancelButton, findsNothing);
  });

  testWidgets('the helmet\'s emergency write landing after the cancel is cleared',
      (tester) async {
    const riding = LinkedRider(
      riderId: 'R-001', fullName: 'Rider One', helmetId: 'NR-H1-001', status: 'riding',
    );
    final repo = await _pump(tester, rider: riding, alerts: [_crash()]);

    await tester.tap(_cancelButton);
    await _frames(tester);
    expect(repo.calls, ['cancel A-1 R-001'], reason: 'not in emergency yet');

    repo.emitAlerts([_crash(status: RiderAlertStatus.cancelled)]);
    repo.emitRider(_rider);
    await _frames(tester);

    expect(repo.calls, ['cancel A-1 R-001', 'standDown R-001 A-1']);
  });

  testWidgets('but not while another crash or SOS is live', (tester) async {
    const riding = LinkedRider(
      riderId: 'R-001', fullName: 'Rider One', helmetId: 'NR-H1-001', status: 'riding',
    );
    final repo = await _pump(tester, rider: riding, alerts: [_crash()]);

    await tester.tap(_cancelButton);
    await _frames(tester);
    repo.emitAlerts([
      _crash(status: RiderAlertStatus.cancelled),
      _crash(id: 'sos', type: 'sos', status: RiderAlertStatus.open),
    ]);
    repo.emitRider(_rider);
    await _frames(tester);

    expect(repo.calls, ['cancel A-1 R-001'],
        reason: 'the red dot belongs to the SOS now');
  });
}
