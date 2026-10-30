// The helmet's deviceStatus node on the rider home screen.
//
// One rule above the rest: a reading the helmet did not send is an em
// dash, never 0. An absent alcohol index rendered as 0 is "not measured"
// shown as "sober".

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/core/widgets/unavailable.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/rider/domain/entities/helmet_telemetry.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_helmet_telemetry_repository.dart';
import 'support/mobile_app.dart';

/// Only the fields confirmed present on the live node — no fix, no speed.
Map<Object?, Object?> _liveNode({DateTime? lastSeen}) => {
      'deviceId': 'tracker-001',
      'online': true,
      'ip': 'cellular',
      'lastSeen':
          (lastSeen ?? DateTime.now()).millisecondsSinceEpoch,
      'cellularDataReady': true,
      'accelerometerReady': true,
      'accelMagnitudeG': 1.012,
      'alcoholRelativeIndex': 512.0,
      'alcoholAlert': false,
      'mq3Raw': 512,
      'mq3Voltage': 0.412,
      'gpsNmeaChars': 18000,
      'gpsValidSentences': 240,
    };

void main() {
  silenceAppLogger();

  group('parsing', () {
    test('a field that is not there is null, not a default', () {
      final t = HelmetTelemetry.fromMap(_liveNode());
      expect(t.accelMagnitudeG, 1.012);
      expect(t.alcoholRelativeIndex, 512);
      expect(t.lat, isNull);
      expect(t.lng, isNull);
      expect(t.speedKmph, isNull);
      expect(t.satellites, isNull);
      expect(t.hasUsableFix, isNull);
    });

    test('a value of the wrong type is absent, not coerced', () {
      final t = HelmetTelemetry.fromMap({
        'alcoholRelativeIndex': '512',
        'online': 'true',
        'lastSeen': 'yesterday',
        'mq3Raw': 1.5,
      });
      expect(t.alcoholRelativeIndex, isNull);
      expect(t.online, isNull);
      expect(t.lastSeen, isNull);
      expect(t.mq3Raw, isNull);
    });

    test('lastSeen is a server timestamp in epoch milliseconds', () {
      final t = HelmetTelemetry.fromMap({'lastSeen': 1761800000000});
      expect(t.lastSeen,
          DateTime.fromMillisecondsSinceEpoch(1761800000000, isUtc: true));
    });

    // The firmware writes the magnitude whether or not the sensor is up,
    // so a dead accelerometer arrives as 0.000.
    test('no impact reading while the accelerometer is not ready', () {
      final t = HelmetTelemetry.fromMap(
          {..._liveNode(), 'accelerometerReady': false, 'accelMagnitudeG': 0});
      expect(t.impactG, isNull);
    });

    test('a position is usable only while it is recent', () {
      final fresh = {'lat': 14.6, 'lng': 121.0, 'gpsAgeMs': 2000};
      expect(HelmetTelemetry.fromMap(fresh).hasUsableFix, isTrue);
      expect(HelmetTelemetry.fromMap({...fresh, 'gpsAgeMs': 60000})
          .hasUsableFix, isFalse);
    });
  });

  group('rider home', () {
    const rider = UserProfile(
      uid: 'uid-rider',
      email: 'juan@example.test',
      username: 'juandc',
      fullName: 'Juan Dela Cruz',
      role: UserRole.rider,
      emailVerified: true,
      phoneNumber: '09171234567',
    );

    Future<void> showHome(
        WidgetTester tester, FakeHelmetTelemetryRepository helmet,
        {bool settle = true}) async {
      final repository = FakeAuthRepository(
        accounts: {'juan@example.test': ('rider123', rider)},
        usernames: const {'juandc': 'juan@example.test'},
      );
      addTearDown(repository.dispose);
      await pumpMobileApp(tester,
          repository: repository, helmetTelemetry: helmet);
      repository.emit(rider);
      await tester.pumpAndSettle();
    }

    testWidgets('a live helmet shows what it sent and dashes the rest',
        (tester) async {
      await showHome(tester,
          FakeHelmetTelemetryRepository(
              telemetry: HelmetTelemetry.fromMap(_liveNode())));

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('1.01 g'), findsOneWidget);
      expect(find.text('512'), findsOneWidget);
      expect(find.text('RAW ALCOHOL INDEX'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      // No position on this node: not "NO FIX", which would be a claim.
      expect(find.text('NO FIX'), findsNothing);
      expect(find.text('NO READING'), findsOneWidget);
      // Speed is absent too, so the trip card is still all dashes.
      expect(
        find.textContaining(Unavailable.dash, findRichText: true),
        findsNWidgets(6),
      );
    });

    testWidgets('a missing alcohol index is a dash, never 0', (tester) async {
      final node = _liveNode()..remove('alcoholRelativeIndex');
      await showHome(tester,
          FakeHelmetTelemetryRepository(
              telemetry: HelmetTelemetry.fromMap(node)));

      expect(find.text('0'), findsNothing);
      expect(find.text('NO READING'), findsNWidgets(2)); // alcohol, location
    });

    testWidgets('the device alert shows on the alcohol tile', (tester) async {
      await showHome(tester,
          FakeHelmetTelemetryRepository(
              telemetry: HelmetTelemetry.fromMap(
                  {..._liveNode(), 'alcoholAlert': true})));
      expect(find.text('ALERT'), findsOneWidget);
    });

    testWidgets('a quiet helmet is offline even though it says online',
        (tester) async {
      final node = _liveNode(
          lastSeen: DateTime.now().subtract(const Duration(minutes: 10)));
      await showHome(tester,
          FakeHelmetTelemetryRepository(
              telemetry: HelmetTelemetry.fromMap(node)));

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
      expect(find.text('STALE'), findsNWidgets(2)); // impact, alcohol
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('nothing at that id is "No helmet"', (tester) async {
      await showHome(tester, FakeHelmetTelemetryRepository());
      expect(find.text('No helmet'), findsOneWidget);
      expect(find.text('NO HELMET'), findsNWidgets(3));
    });

    testWidgets('before the first snapshot it says so', (tester) async {
      final controller = StreamController<HelmetTelemetry?>();
      addTearDown(controller.close);
      await showHome(
          tester, FakeHelmetTelemetryRepository.controlled(controller));

      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.text('CONNECTING…'), findsNWidgets(3));
    });

    testWidgets('a stream error shows its sentence, not a number',
        (tester) async {
      final controller = StreamController<HelmetTelemetry?>();
      addTearDown(controller.close);
      await showHome(
          tester, FakeHelmetTelemetryRepository.controlled(controller));

      controller.addError(const PermissionFailure('Not allowed to read.'));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Not allowed to read.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text(Unavailable.dash), findsNWidgets(5));
    });
  });
}
