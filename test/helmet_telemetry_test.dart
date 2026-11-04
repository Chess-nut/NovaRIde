// The helmet's deviceStatus node on the rider home screen.
//
// One rule above the rest: a reading the helmet did not send is an em
// dash, never 0. An absent alcohol index rendered as 0 is "not measured"
// shown as "sober".

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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
  'lastSeen': (lastSeen ?? DateTime.now()).millisecondsSinceEpoch,
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
      expect(
        t.lastSeen,
        DateTime.fromMillisecondsSinceEpoch(1761800000000, isUtc: true),
      );
    });

    // The firmware writes the magnitude whether or not the sensor is up,
    // so a dead accelerometer arrives as 0.000.
    test('no impact reading while the accelerometer is not ready', () {
      final t = HelmetTelemetry.fromMap({
        ..._liveNode(),
        'accelerometerReady': false,
        'accelMagnitudeG': 0,
      });
      expect(t.impactG, isNull);
    });

    test('a position is usable only while it is recent', () {
      final fresh = {'lat': 14.6, 'lng': 121.0, 'gpsAgeMs': 2000};
      expect(HelmetTelemetry.fromMap(fresh).hasUsableFix, isTrue);
      expect(
        HelmetTelemetry.fromMap({...fresh, 'gpsAgeMs': 60000}).hasUsableFix,
        isFalse,
      );
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
      WidgetTester tester,
      FakeHelmetTelemetryRepository helmet, {
      bool settle = true,
    }) async {
      final repository = FakeAuthRepository(
        accounts: {'juan@example.test': ('rider123', rider)},
        usernames: const {'juandc': 'juan@example.test'},
      );
      addTearDown(repository.dispose);
      await pumpMobileApp(
        tester,
        repository: repository,
        helmetTelemetry: helmet,
      );
      repository.emit(rider);
      await tester.pumpAndSettle();
    }

    testWidgets('a live helmet shows what it sent and dashes the rest', (
      tester,
    ) async {
      await showHome(
        tester,
        FakeHelmetTelemetryRepository(
          telemetry: HelmetTelemetry.fromMap(_liveNode()),
        ),
      );

      expect(find.text('Helmet connected'), findsOneWidget);
      expect(find.text('1.01'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
      expect(find.text('512'), findsOneWidget);
      expect(find.text('raw index'), findsOneWidget);
      // The helmet's own verdict, sent as alcoholAlert: false.
      expect(find.text('Below threshold'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      // No position on this node: not "No fix", which would be a claim.
      expect(find.text('No fix'), findsNothing);
      expect(find.text('No reading'), findsNWidgets(2)); // posture, location
      // The status pill, and impact's status line.
      expect(find.text('Live'), findsNWidgets(2));
      // Posture, location and speed have nothing behind them.
      expect(find.text(Unavailable.dash), findsNWidgets(3));
    });

    testWidgets('a missing alcohol index is a dash, never 0', (tester) async {
      final node = _liveNode()..remove('alcoholRelativeIndex');
      await showHome(
        tester,
        FakeHelmetTelemetryRepository(telemetry: HelmetTelemetry.fromMap(node)),
      );

      expect(find.text('0'), findsNothing);
      expect(find.text('Below threshold'), findsNothing);
      // Alcohol, posture, location.
      expect(find.text('No reading'), findsNWidgets(3));
    });

    testWidgets('the device alert takes over the status card', (tester) async {
      await showHome(
        tester,
        FakeHelmetTelemetryRepository(
          telemetry: HelmetTelemetry.fromMap({
            ..._liveNode(),
            'alcoholAlert': true,
          }),
        ),
      );
      expect(find.text('Alcohol detected'), findsOneWidget);
      expect(find.text('Above threshold'), findsOneWidget);
      expect(find.text('Helmet connected'), findsNothing);
    });

    testWidgets('a quiet helmet is offline even though it says online', (
      tester,
    ) async {
      final node = _liveNode(
        lastSeen: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      await showHome(
        tester,
        FakeHelmetTelemetryRepository(telemetry: HelmetTelemetry.fromMap(node)),
      );

      expect(find.text('Helmet offline'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Helmet connected'), findsNothing);
      expect(find.text('Stale'), findsNWidgets(2)); // impact, alcohol
      expect(find.text('Live'), findsNothing);
      // An old verdict is not repeated as if it were current.
      expect(find.text('Below threshold'), findsNothing);
    });

    testWidgets('nothing at that id is "No helmet"', (tester) async {
      await showHome(tester, FakeHelmetTelemetryRepository());
      // The status card, and each of the four sensors.
      expect(find.text('No helmet'), findsNWidgets(5));
    });

    testWidgets('before the first snapshot it says so', (tester) async {
      final controller = StreamController<HelmetTelemetry?>();
      addTearDown(controller.close);
      await showHome(
        tester,
        FakeHelmetTelemetryRepository.controlled(controller),
      );

      expect(find.text('Connecting to helmet…'), findsOneWidget);
      expect(find.text('Connecting…'), findsNWidgets(4));
    });

    testWidgets('a stream error shows its sentence, not a number', (
      tester,
    ) async {
      final controller = StreamController<HelmetTelemetry?>();
      addTearDown(controller.close);
      await showHome(
        tester,
        FakeHelmetTelemetryRepository.controlled(controller),
      );

      controller.addError(const PermissionFailure('Not allowed to read.'));
      await tester.pumpAndSettle();

      expect(find.text('Can\'t reach helmet data'), findsOneWidget);
      expect(find.text('Not allowed to read.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Error'), findsNWidgets(4));
      // Four sensors and the speed.
      expect(find.text(Unavailable.dash), findsNWidgets(5));
    });

    // Signal's smallest step is the 12px caption. The old home went down
    // to 9px, which a rider glancing at a mounted phone cannot read.
    testWidgets('no text is smaller than 12px', (tester) async {
      await showHome(
        tester,
        FakeHelmetTelemetryRepository(
          telemetry: HelmetTelemetry.fromMap(_liveNode()),
        ),
      );

      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.byType(RichText),
      )) {
        final size = paragraph.text.style?.fontSize;
        if (size == null) continue;
        expect(
          size,
          greaterThanOrEqualTo(12),
          reason: '"${paragraph.text.toPlainText()}" is ${size}px',
        );
      }
    });
  });
}
