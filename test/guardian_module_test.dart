// The guardian app: connecting with a code, what a linked guardian sees,
// and the four tabs. Everything runs on fakes; nothing touches Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/features/guardian/domain/entities/guardian_link.dart';
import 'package:novaride/features/guardian/presentation/pages/guardian_connect_view.dart';
import 'package:novaride/features/guardian/presentation/pages/guardian_home_page.dart';
import 'package:novaride/features/rider/domain/entities/helmet_telemetry.dart';
import 'package:novaride/features/rider/domain/entities/rider_alert.dart';

import 'support/fake_guardian_link_repository.dart';
import 'support/fake_helmet_telemetry_repository.dart';
import 'support/fake_rider_alert_repository.dart';
import 'support/mobile_app.dart';

final _guardian = AuthState.signedIn(
  profileFor(UserRole.guardian, uid: 'uid-guardian'),
);

const _rider = FollowedRiderAccount(
  uid: 'uid-rider',
  fullName: 'Juan Dela Cruz',
  username: 'juandc',
  phoneNumber: '+63 917 000 0000',
);

final _link = GuardianLink(
  guardianUid: 'uid-guardian',
  riderUid: 'uid-rider',
  guardianName: 'Test Person',
  relationship: 'Sibling',
  createdAt: DateTime(2026, 11, 5),
);

const _roster = LinkedRider(
  riderId: 'R-001',
  fullName: 'Juan Dela Cruz',
  helmetId: 'NR-H1-001',
  status: 'riding',
);

HelmetTelemetry _live({double speed = 24}) => HelmetTelemetry(
      online: true,
      lastSeen: DateTime.now(),
      ip: 'cellular',
      accelerometerReady: true,
      alcoholAlert: false,
      lat: 14.30416,
      lng: 121.07812,
      speedKmph: speed,
      satellites: 9,
      gpsAgeMs: 1000,
    );

RiderAlert _alert(String id, String type, RiderAlertStatus status, DateTime at) =>
    RiderAlert(
      id: id,
      riderId: 'R-001',
      type: type,
      severity: 'high',
      status: status,
      timestamp: at,
    );

Future<void> _pumpLinked(
  WidgetTester tester, {
  HelmetTelemetry? telemetry,
  List<RiderAlert> alerts = const [],
  FakeGuardianLinkRepository? links,
}) {
  return pumpMobileApp(
    tester,
    auth: _guardian,
    guardianLinks: links ?? FakeGuardianLinkRepository(link: _link, riderAccount: _rider),
    riderAlerts: FakeRiderAlertRepository(rider: _roster, alerts: alerts),
    helmetTelemetry: FakeHelmetTelemetryRepository(telemetry: telemetry),
  );
}

void main() {
  silenceAppLogger();

  group('a guardian who follows nobody yet', () {
    testWidgets('is asked for the rider\'s code, with no tabs', (tester) async {
      await pumpMobileApp(tester, auth: _guardian);

      expect(find.byType(GuardianConnectView), findsOneWidget);
      expect(find.text('Connect to a rider'), findsOneWidget);
      expect(find.text('Where to get the code'), findsOneWidget);
      expect(find.text('Map'), findsNothing);
    });

    testWidgets('connects with a code typed any way and a relationship',
        (tester) async {
      final links = FakeGuardianLinkRepository(riderAccount: _rider);
      await pumpMobileApp(tester, auth: _guardian, guardianLinks: links);

      // Nothing happens without both.
      await tester.tap(find.text('Connect to rider'));
      await tester.pumpAndSettle();
      expect(links.calls, isEmpty);

      await tester.enterText(find.byType(TextField), 'k7p 2qm');
      await tester.tap(find.text('Sibling'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Connect to rider'));
      await tester.tap(find.text('Connect to rider'));
      await tester.pumpAndSettle();

      expect(links.calls,
          contains('redeem:K7P2QM|uid-guardian|Test Person|Sibling'));
      // Linking swaps the connect screen for the rider's dashboard.
      expect(find.byType(GuardianConnectView), findsNothing);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
    });
  });

  group('a linked guardian\'s Home', () {
    testWidgets('names the rider and shows them riding, live', (tester) async {
      await _pumpLinked(tester, telemetry: _live());

      expect(find.byType(GuardianHomePage), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Sibling · you\'re their guardian'), findsOneWidget);
      expect(find.text('Riding now'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('says offline, with no speed, when the helmet went quiet',
        (tester) async {
      final stale = HelmetTelemetry(
        online: true,
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
        lat: 14.3,
        lng: 121.0,
        speedKmph: 40,
      );
      await _pumpLinked(tester, telemetry: stale);

      expect(find.text('Helmet offline'), findsOneWidget);
      expect(find.text('40'), findsNothing);
      expect(find.text('Last known location'), findsOneWidget);
    });

    testWidgets('counts the safety summary from real alerts', (tester) async {
      final now = DateTime.now();
      await _pumpLinked(tester, telemetry: _live(), alerts: [
        _alert('a1', 'alcoholWarning', RiderAlertStatus.resolved,
            now.subtract(const Duration(days: 3))),
        _alert('a2', 'crash', RiderAlertStatus.resolved,
            now.subtract(const Duration(days: 10))),
      ]);

      await tester.ensureVisible(find.text('Safety summary'));
      expect(find.text('Crashes'), findsOneWidget);
      expect(find.text('3 days since the last alert'), findsOneWidget);
      // No invented trip numbers.
      expect(find.textContaining('Trip'), findsNothing);
      expect(find.textContaining('Battery'), findsNothing);
    });

    testWidgets('a crash still being worked takes over the screen',
        (tester) async {
      await _pumpLinked(tester, telemetry: _live(), alerts: [
        _alert('c1', 'crash', RiderAlertStatus.open,
            DateTime.now().subtract(const Duration(minutes: 2))),
      ]);

      expect(find.text('Crash detected'), findsWidgets);
      expect(find.text('Waiting for responders'), findsOneWidget);
      expect(find.text('Call Juan'), findsOneWidget);
      expect(find.text('Riding now'), findsNothing);
      await tester.ensureVisible(find.text('What has happened'));
      expect(find.text('Countdown ended'), findsOneWidget);
    });

    testWidgets('notes when operations hasn\'t linked a helmet', (tester) async {
      await pumpMobileApp(
        tester,
        auth: _guardian,
        guardianLinks: FakeGuardianLinkRepository(link: _link, riderAccount: _rider),
        riderAlerts: FakeRiderAlertRepository(),
      );
      expect(find.textContaining('hasn\'t linked Juan\'s account'), findsOneWidget);
    });
  });

  group('the tabs', () {
    testWidgets('are Home, Map, Alerts and Profile — no History',
        (tester) async {
      await _pumpLinked(tester, telemetry: _live());

      for (final label in ['Home', 'Map', 'Alerts', 'Profile']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('History'), findsNothing);
    });

    testWidgets('Alerts splits now from past', (tester) async {
      await _pumpLinked(tester, telemetry: _live(), alerts: [
        _alert('a1', 'alcoholWarning', RiderAlertStatus.resolved,
            DateTime.now().subtract(const Duration(days: 3))),
      ]);
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();

      expect(find.text('Happening now'), findsOneWidget);
      expect(find.text('Nothing right now.'), findsOneWidget);
      expect(find.text('Past incidents'), findsOneWidget);
      expect(find.text('Alcohol warning'), findsOneWidget);
    });

    testWidgets('Map gives coordinates and speed while live', (tester) async {
      await _pumpLinked(tester, telemetry: _live());
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      expect(find.text('14.30416° N'), findsOneWidget);
      expect(find.text('24 km/h'), findsOneWidget);
      expect(find.text('Open in Google Maps'), findsOneWidget);
    });

    testWidgets('Profile unlinks after a confirmation', (tester) async {
      final links = FakeGuardianLinkRepository(link: _link, riderAccount: _rider);
      await _pumpLinked(tester, telemetry: _live(), links: links);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Rider you follow'), findsOneWidget);
      await tester.tap(find.text('Unlink from Juan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      expect(links.calls, contains('unlink:uid-guardian'));
    });
  });
}
