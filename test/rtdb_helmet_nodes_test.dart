// Merging the helmet's Realtime Database nodes, and what Home makes of the
// result. The first fixture is the live database as it stood on Oct 30
// (copied from the console), junk zeros and all.

import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/rider/data/rtdb_helmet_nodes.dart';
import 'package:novaride/features/rider/domain/entities/helmet_telemetry.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_helmet_telemetry_repository.dart';
import 'support/mobile_app.dart';

DateTime _ms(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

/// deviceStatus/tracker-001, as the current firmware writes it: no GPS.
Map<Object?, Object?> _status({int lastSeen = 1793352300144, Map<Object?, Object?> extra = const {}}) => {
      'deviceId': 'tracker-001',
      'online': true,
      'ip': '10.53.217.66',
      'accelerometerReady': true,
      'accelMagnitudeG': 1.111,
      'alcoholAlert': false,
      'alcoholRelativeIndex': 187,
      'mq3Raw': 187,
      'mq3Voltage': 0.151,
      'orientation': 'Side/abnormal',
      'sw420Active': true,
      'tiltDegrees': 40.4,
      'lastSeen': lastSeen,
      ...extra,
    };

/// devices/tracker-001 with its three children, as on Oct 30.
Map<Object?, Object?> _device({int safetyTime = 1793352323540}) => {
      'latest': {
        'deviceId': 'tracker-001',
        'lat': 0,
        'lng': 0.366667,
        'satellites': 0,
        'gpsAgeMs': 186279,
        'speedKmph': 0,
        'serverTime': 1793351206896,
        'reason': 'suspected-crash',
      },
      'safety': {
        'deviceId': 'tracker-001',
        'alcoholAlert': false,
        'alcoholRelativeIndex': 174,
        'mpuReady': true,
        'orientation': 'Side/abnormal',
        'tiltDegrees': 70.9,
        'xG': 0.183,
        'yG': -0.991,
        'zG': 0.348,
        'serverTime': safetyTime,
      },
      'tracking': {
        'lat': 0,
        'lng': 0.366667,
        'tiltDegrees': 74.3,
        'serverTime': 1793351016116,
      },
    };

/// trackingLogs/tracker-001: two real fixes, then a pre-lock zero.
const Map<Object?, Object?> _trackingLogs = {
  '-PSBGZsc2BvMeYWl-0bH': {'lat': 14.304193, 'lng': 121.123406, 'serverTime': 1793304448553},
  '-PSBJfIQX4rvgBiEgC8m': {'lat': 14.304159, 'lng': 121.123368, 'serverTime': 1793305261275},
  '-PSBZD9AcHm8XmD4aKAu': {'lat': 0, 'lng': 0.366667, 'serverTime': 1793351017099},
};

void main() {
  silenceAppLogger();

  group('merging the nodes', () {
    test('nothing anywhere is no helmet, not an empty reading', () {
      expect(mergeHelmetNodes(), isNull);
      expect(mergeHelmetNodes(status: 'not a map', device: 42), isNull);
    });

    test('the live database: newest sensors, newest real position', () {
      final t = mergeHelmetNodes(
        status: _status(),
        device: _device(),
        trackingLogs: _trackingLogs,
      )!;

      // devices/…/safety was written 23 s after the heartbeat, so its
      // readings win, and its time is the last time the helmet was heard.
      expect(t.tiltDegrees, 70.9);
      expect(t.alcoholRelativeIndex, 174);
      expect(t.accelMagnitudeG, closeTo(1.0662, 0.001)); // √(x²+y²+z²)
      expect(t.lastSeen, _ms(1793352323540));
      expect(t.online, isTrue);

      // latest and tracking hold lat 0 — a GPS that has not locked. The
      // newest real position is the second log entry.
      expect(t.lat, 14.304159);
      expect(t.lng, 121.123368);
      expect(t.fixAt, _ms(1793305261275));
      expect(t.positionAt, _ms(1793305261275));
      // The tracking log carries no speed, so none is invented.
      expect(t.speedKmph, isNull);
    });

    test('the heartbeat wins when it is the newer one', () {
      final t = mergeHelmetNodes(
        status: _status(lastSeen: 1793352400000),
        device: _device(),
      )!;
      expect(t.tiltDegrees, 40.4);
      expect(t.accelMagnitudeG, 1.111);
      expect(t.lastSeen, _ms(1793352400000));
    });

    test('zero satellites or a zero coordinate is never a position', () {
      final t = mergeHelmetNodes(status: _status(), device: _device())!;
      expect(t.lat, isNull);
      expect(t.positionAt, isNull);
      expect(t.hasUsableFix, isNull);
    });

    test('a fix on the heartbeat gives a current speed', () {
      final now = DateTime.now().toUtc();
      final t = mergeHelmetNodes(
        status: _status(
          lastSeen: now.millisecondsSinceEpoch,
          extra: {
            'lat': 14.30416,
            'lng': 121.07812,
            'speedKmph': 32.4,
            'satellites': 8,
            'gpsAgeMs': 900,
          },
        ),
        device: const {},
      )!;
      expect(t.speedKmph, 32.4);
      expect(t.hasCurrentFix(now), isTrue);
      expect(t.currentSpeedKmph(now), 32.4);
      // Three minutes later the same reading is no longer "current".
      expect(t.currentSpeedKmph(now.add(const Duration(minutes: 3))), isNull);
    });

    test('a fix that was already old when written is placed by its age', () {
      final t = mergeHelmetNodes(
        status: _status(),
        device: {
          'latest': {
            'lat': 14.3,
            'lng': 121.1,
            'satellites': 6,
            'gpsAgeMs': 60000,
            'speedKmph': 20,
            'serverTime': 1793352400000,
          },
        },
      )!;
      expect(t.fixAt, _ms(1793352400000 - 60000));
      expect(t.hasUsableFix, isFalse); // a minute old when sent
      expect(t.currentSpeedKmph(_ms(1793352400000)), isNull);
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

    Future<void> showHome(WidgetTester tester, HelmetTelemetry? telemetry) async {
      final repository = FakeAuthRepository(
        accounts: {'juan@example.test': ('rider123', rider)},
        usernames: const {'juandc': 'juan@example.test'},
      );
      addTearDown(repository.dispose);
      await pumpMobileApp(
        tester,
        repository: repository,
        helmetTelemetry: FakeHelmetTelemetryRepository(telemetry: telemetry),
      );
      repository.emit(rider);
      await tester.pumpAndSettle();
    }

    testWidgets('a quiet helmet shows its last readings and last fix, '
        'marked as old, and no speed', (tester) async {
      await showHome(
        tester,
        mergeHelmetNodes(
          status: _status(),
          device: _device(),
          trackingLogs: _trackingLogs,
        ),
      );

      expect(find.text('71°'), findsOneWidget); // safety's tilt, rounded
      expect(find.text('174'), findsOneWidget);
      expect(find.text('Last fix'), findsOneWidget);
      expect(find.text('Last known'), findsOneWidget);
      expect(find.text('Speed shows only while the helmet is live.'), findsOneWidget);
    });

    testWidgets('a live helmet with a fresh fix shows its speed', (tester) async {
      final now = DateTime.now().toUtc();
      await showHome(
        tester,
        mergeHelmetNodes(
          status: _status(
            lastSeen: now.millisecondsSinceEpoch,
            extra: {
              'lat': 14.30416,
              'lng': 121.07812,
              'speedKmph': 32.4,
              'satellites': 8,
              'gpsAgeMs': 900,
            },
          ),
          device: const {},
        ),
      );

      expect(find.text('32'), findsOneWidget); // 32.4 km/h, rounded
      expect(find.text('Fix'), findsOneWidget);
      expect(find.text('8 satellites'), findsOneWidget);
      expect(find.text('From the helmet\'s GPS.'), findsOneWidget);
    });

    testWidgets('a live helmet without a fix says it is waiting for one',
        (tester) async {
      await showHome(
        tester,
        mergeHelmetNodes(
          status: _status(lastSeen: DateTime.now().millisecondsSinceEpoch),
          device: const {},
        ),
      );
      expect(
        find.text('Waiting for a GPS fix. The helmet needs a clear view of the sky.'),
        findsOneWidget,
      );
    });
  });
}
