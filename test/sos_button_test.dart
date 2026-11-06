// The SOS button on rider Home: a 10-second countdown that can be
// cancelled, then one SOS alert for operations and the guardians.
//
// The countdown is a real Timer, so these tests pump time by hand rather
// than settling.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/features/rider/domain/entities/rider_alert.dart';
import 'package:novaride/features/rider/presentation/widgets/sos_countdown.dart';

import 'support/fake_rider_alert_repository.dart';
import 'support/mobile_app.dart';

const _rider = LinkedRider(
  riderId: 'R-001',
  fullName: 'Rider One',
  helmetId: 'NR-H1-001',
  status: 'riding',
);

/// Numbers the app tried to call, in order.
final List<String> _dialled = [];

Future<FakeRiderAlertRepository> _pump(
  WidgetTester tester, {
  LinkedRider? rider = _rider,
}) async {
  _dialled.clear();
  final repo = FakeRiderAlertRepository(rider: rider);
  await pumpMobileApp(
    tester,
    auth: AuthState.signedIn(profileFor(UserRole.rider)),
    riderAlerts: repo,
    extraOverrides: [
      sosCallerProvider.overrideWithValue((number) async {
        _dialled.add(number);
      }),
    ],
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

Future<void> _seconds(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await _frames(tester);
}

Future<void> _pressSos(WidgetTester tester) async {
  await tester.ensureVisible(find.text('SOS'));
  await tester.tap(find.text('SOS'));
  await _frames(tester);
}

int _shownSeconds(WidgetTester tester) => int.parse(
  tester.widget<Text>(find.byKey(const ValueKey('sos-seconds'))).data!,
);

void main() {
  silenceAppLogger();

  testWidgets('pressing SOS starts a 10-second countdown, nothing sent yet', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await _pressSos(tester);

    expect(find.text('SENDING SOS IN'), findsOneWidget);
    expect(_shownSeconds(tester), 10);
    await _seconds(tester, 3);
    expect(_shownSeconds(tester), 7);
    expect(repo.calls, isEmpty);
    expect(_dialled, isEmpty);
  });

  testWidgets('Cancel means nothing is ever sent', (tester) async {
    final repo = await _pump(tester);
    await _pressSos(tester);

    await tester.tap(find.text('CANCEL — I\'M OK'));
    await _seconds(tester, 12);

    expect(find.text('SENDING SOS IN'), findsNothing);
    expect(repo.calls, isEmpty);
    expect(_dialled, isEmpty);
  });

  testWidgets('after 10 seconds one SOS goes out and the phone calls 122', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await _pressSos(tester);
    await _seconds(tester, 10);

    expect(repo.calls, ['sos R-001']);
    expect(_dialled, ['122']);
    expect(find.text('SOS sent'), findsOneWidget);

    await _seconds(tester, 5);
    expect(repo.calls, hasLength(1)); // never twice
    expect(_dialled, hasLength(1));
  });

  testWidgets('Send now skips the wait', (tester) async {
    final repo = await _pump(tester);
    await _pressSos(tester);

    await tester.tap(find.text('SEND NOW'));
    await _frames(tester);

    expect(repo.calls, ['sos R-001']);
    expect(_dialled, ['122']);
    expect(find.text('SOS sent'), findsOneWidget);
  });

  testWidgets('no connection: it says the SOS is queued, not sent', (
    tester,
  ) async {
    final repo = await _pump(tester)..holdSos = Completer<void>();
    await _pressSos(tester);
    await tester.tap(find.text('SEND NOW'));
    await _frames(tester);
    expect(find.text('Sending SOS…'), findsOneWidget);

    expect(_dialled, ['122']); // the call does not wait for the server
    await _seconds(tester, 16);
    expect(find.text('Not confirmed yet'), findsOneWidget);

    repo.holdSos!.complete();
    await _frames(tester);
    expect(find.text('SOS sent'), findsOneWidget);
  });

  testWidgets('a refusal offers Try again and 122', (tester) async {
    final repo = await _pump(tester)
      ..failSosWith = const PermissionFailure('refused');
    await _pressSos(tester);
    await tester.tap(find.text('SEND NOW'));
    await _frames(tester);

    expect(find.text('SOS didn\'t go through'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('CALL 122'), findsOneWidget);

    repo.failSosWith = null;
    await tester.tap(find.text('TRY AGAIN'));
    await _frames(tester);
    expect(find.text('SOS sent'), findsOneWidget);
    expect(repo.calls, ['sos R-001', 'sos R-001']);
    expect(_dialled, ['122']); // the retry does not ring again
  });

  testWidgets('an unlinked account is told straight away, nothing sent', (
    tester,
  ) async {
    final repo = await _pump(tester, rider: null);
    await _pressSos(tester);

    expect(find.text('SOS can\'t reach operations yet'), findsOneWidget);
    expect(find.text('CALL 122'), findsOneWidget);
    await _seconds(tester, 11);
    expect(repo.calls, isEmpty);
    expect(_dialled, isEmpty); // no countdown ran, so no automatic call

    await tester.tap(find.text('CALL 122'));
    await _frames(tester);
    expect(_dialled, ['122']);
  });
}
