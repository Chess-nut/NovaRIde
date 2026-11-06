// The admin console's merge of the helmet's Realtime Database nodes
// (lib/admin/data/rtdb_fleet_merge.dart). The fixtures are the rider app's
// (test/rtdb_helmet_nodes_test.dart) — the live database as it stood on
// Oct 30, junk zeros and all — so the two copies of the merge cannot drift
// apart without a test saying so. The rider-home widget tests stay there.

import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/admin/data/rtdb_fleet_merge.dart';
import 'package:novaride/shared/models/models.dart';

DateTime _ms(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

/// deviceStatus/tracker-001, as the current firmware writes it: no GPS.
Map<Object?, Object?> _status({
  int lastSeen = 1793352300144,
  Map<Object?, Object?> extra = const {},
}) => {
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
Map<Object?, Object?> _device({
  int safetyTime = 1793352323540,
  Map<Object?, Object?> safetyExtra = const {},
}) => {
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
    ...safetyExtra,
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
  '-PSBGZsc2BvMeYWl-0bH': {
    'lat': 14.304193,
    'lng': 121.123406,
    'serverTime': 1793304448553,
  },
  '-PSBJfIQX4rvgBiEgC8m': {
    'lat': 14.304159,
    'lng': 121.123368,
    'serverTime': 1793305261275,
  },
  '-PSBZD9AcHm8XmD4aKAu': {
    'lat': 0,
    'lng': 0.366667,
    'serverTime': 1793351017099,
  },
};

HelmetTelemetry? _merge({
  Object? status,
  Object? device,
  Object? trackingLogs,
  Object? gpsLogs,
  DateTime? now,
}) => mergeFleetNodes(
  deviceId: 'tracker-001',
  status: status,
  device: device,
  trackingLogs: trackingLogs,
  gpsLogs: gpsLogs,
  now: now ?? _ms(1793352400000),
);

void main() {
  group('merging the nodes (ported from the rider app)', () {
    test('nothing anywhere is no helmet, not an empty reading', () {
      expect(_merge(), isNull);
      expect(_merge(status: 'not a map', device: 42), isNull);
    });

    test('the live database: newest sensors, newest real position', () {
      final t = _merge(
        status: _status(),
        device: _device(),
        trackingLogs: _trackingLogs,
      )!;

      // devices/…/safety was written 23 s after the heartbeat, so its
      // readings win, and its time is the last time the helmet was heard.
      expect(t.tiltDegrees, 70.9);
      expect(t.alcoholRawIndex, 174);
      expect(t.accelMagnitudeG, closeTo(1.0662, 0.001)); // √(x²+y²+z²)
      expect(t.lastSeen, _ms(1793352323540));
      expect(t.lastUpdate, _ms(1793352323540));
      expect(t.online, isTrue);

      // latest and tracking hold lat 0 — a GPS that has not locked. The
      // newest real position is the second log entry.
      expect(t.lat, 14.304159);
      expect(t.lng, 121.123368);
      expect(t.fixAt, _ms(1793305261275));
      expect(t.positionSource, PositionSource.trackingLogs);
      // The tracking log carries no speed, so none is invented — and the
      // fix is 13 hours old, so it is not current either.
      expect(t.speedKmh, isNull);
      expect(t.gpsFix, isFalse);
      // The RTDB firmware sends no battery reading.
      expect(t.batteryPct, isNull);
    });

    test('the heartbeat wins when it is the newer one', () {
      final t = _merge(
        status: _status(lastSeen: 1793352400000),
        device: _device(),
      )!;
      expect(t.tiltDegrees, 40.4);
      expect(t.accelMagnitudeG, 1.111);
      expect(t.lastSeen, _ms(1793352400000));
    });

    test('zero satellites or a zero coordinate is never a position', () {
      final t = _merge(status: _status(), device: _device())!;
      expect(t.lat, isNull);
      expect(t.lng, isNull);
      expect(t.fixAt, isNull);
      expect(t.positionSource, isNull);
      expect(t.gpsFix, isFalse);
    });

    test('a fix on the heartbeat gives a current speed', () {
      final now = DateTime.now().toUtc();
      Map<Object?, Object?> status() => _status(
        lastSeen: now.millisecondsSinceEpoch,
        extra: {
          'lat': 14.30416,
          'lng': 121.07812,
          'speedKmph': 32.4,
          'satellites': 8,
          'gpsAgeMs': 900,
        },
      );
      final t = _merge(status: status(), device: const {}, now: now)!;
      expect(t.speedKmh, 32.4);
      expect(t.gpsFix, isTrue);
      expect(t.satellites, 8);
      expect(t.positionSource, PositionSource.deviceStatus);
      // Past the 7-minute window the same reading is no longer current.
      final later = _merge(
        status: status(),
        device: const {},
        now: now.add(const Duration(minutes: 8)),
      )!;
      expect(later.speedKmh, isNull);
      expect(later.gpsFix, isFalse);
      expect(later.lat, 14.30416, reason: 'still the last known position');
    });

    test('a fix that was already old when written is placed by its age', () {
      final t = _merge(
        status: _status(),
        device: {
          'latest': {
            'lat': 14.3,
            'lng': 121.1,
            'satellites': 6,
            'gpsAgeMs': 60000,
            'speedKmph': 20,
            'serverTime': 1793352400000,
            'mapsUrl': 'https://maps.google.com/?q=14.3,121.1',
          },
        },
        now: _ms(1793352400000),
      )!;
      expect(t.fixAt, _ms(1793352400000 - 60000));
      expect(t.gpsAgeMs, 60000);
      expect(t.mapsUrl, 'https://maps.google.com/?q=14.3,121.1');
      expect(t.gpsFix, isFalse); // a minute old when sent
      expect(t.speedKmh, isNull);
    });
  });

  group('admin additions', () {
    test('fields only one node carries survive the other winning', () {
      // The heartbeat is newer, but only safety carries the threshold and,
      // on this firmware, the safety event.
      final t = _merge(
        status: _status(lastSeen: 1793352400000),
        device: _device(
          safetyExtra: {
            'alcoholThreshold': 900,
            'safetyEvent': 'Tilt/side posture: monitoring',
          },
        ),
      )!;
      expect(t.tiltDegrees, 40.4, reason: 'the winner still wins');
      expect(t.alcoholThreshold, 900);
      expect(t.safetyEvent, 'Tilt/side posture: monitoring');
      expect(t.ip, '10.53.217.66');
      expect(t.alcoholThresholdLabel, 'Raw 187 / threshold 900 — Below threshold');
    });

    test('accelerometer down: the zeros it sends are not readings', () {
      final t = _merge(
        status: _status(
          lastSeen: 1793352400000,
          extra: {'accelerometerReady': false, 'accelMagnitudeG': 0.0},
        ),
        device: const {},
      )!;
      expect(t.accelMagnitudeG, isNull);
      expect(t.accelerometerReady, isFalse);
    });

    test('a value of the wrong type is absent, never coerced', () {
      final t = _merge(
        status: _status(extra: {'tiltDegrees': '40', 'sw420Active': 1}),
        device: const {},
      )!;
      expect(t.tiltDegrees, isNull);
      expect(t.sw420Active, isNull);
      expect(t.tiltLabel, 'Side/abnormal');
      expect(t.vibrationLabel, '—');
    });

    test('fix history: real fixes only, oldest first, no repeats', () {
      final fixes = fixHistoryFromNodes(
        status: _status(),
        device: {
          ..._device(),
          'tracking': {
            'lat': 14.304159,
            'lng': 121.123368,
            'serverTime': 1793305261280, // the same upload as the log entry
          },
        },
        trackingLogs: _trackingLogs,
        gpsLogs: const {
          '-a': {
            'lat': 14.31,
            'lng': 121.13,
            'satellites': 7,
            'gpsAgeMs': 1000,
            'speedKmph': 12.5,
            'reason': 'suspected-crash',
            'serverTime': 1793306000000,
          },
        },
      );
      expect(fixes.map((f) => f.at), [
        _ms(1793304448553),
        _ms(1793305261275),
        _ms(1793306000000 - 1000),
      ]);
      expect(fixes.last.source, PositionSource.gpsLogs);
      expect(fixes.last.reason, 'suspected-crash');
      expect(fixes.any((f) => f.lat == 0), isFalse);
    });

    test('the last fix at or before a time', () {
      final fixes = fixHistoryFromNodes(trackingLogs: _trackingLogs);
      expect(lastFixAtOrBefore(fixes, _ms(1793305000000))!.lat, 14.304193);
      expect(lastFixAtOrBefore(fixes, _ms(1793399999999))!.lat, 14.304159);
      expect(lastFixAtOrBefore(fixes, _ms(1793300000000)), isNull);
    });

    test('log entries that are not maps are skipped, not fatal', () {
      final entries = logEntries({'-a': 'junk', '-b': {'lat': 1}, '-c': 3});
      expect(entries.map((e) => e.key), ['-b']);
      expect(logEntries('nothing'), isEmpty);
    });
  });

  group('helmet events', () {
    Map<Object?, Object?> device(String safetyEvent, int at, {bool alcohol = false}) => {
      'safety': {
        'safetyEvent': safetyEvent,
        'alcoholAlert': alcohol,
        'alcoholRelativeIndex': alcohol ? 934 : 210,
        'alcoholThreshold': 900,
        'sw420Active': false,
        'serverTime': at,
      },
    };

    test('a crash state is one event, with a deterministic id', () {
      final tracker = RtdbHelmetTracker();
      tracker.observe('tracker-001', device: device('Monitoring', 1000000));
      expect(tracker.events, isEmpty);

      final changed = tracker.observe(
        'tracker-001',
        device: device('Crash alert: abnormal posture persisted 12 minutes', 1010000),
      );
      expect(changed, isTrue);
      expect(tracker.events.single.id, 'tracker-001_1010000');
      expect(tracker.events.single.kind, HelmetEventKind.crash);
      expect(tracker.events.single.at, _ms(1010000));

      // The node is rewritten every 10 s; the state has not changed.
      tracker.observe(
        'tracker-001',
        device: device('Crash alert: abnormal posture persisted 12 minutes', 1020000),
      );
      expect(tracker.events, hasLength(1));

      // Cleared, then back: a second incident.
      tracker.observe('tracker-001', device: device('Monitoring', 1030000));
      tracker.observe(
        'tracker-001',
        device: device('Crash alert: GPS stationary, no vibration', 1040000),
      );
      expect(tracker.events.map((e) => e.id), [
        'tracker-001_1040000',
        'tracker-001_1010000',
      ]);
    });

    test('a rider check is its own kind', () {
      final tracker = RtdbHelmetTracker();
      tracker.observe(
        'tracker-001',
        device: device('Rider check alert: posture unchanged', 2000000),
      );
      expect(tracker.events.single.kind, HelmetEventKind.riderCheck);
      expect(tracker.events.single.kind.alertType, AlertType.crash);
      expect(tracker.events.single.kind.severity, 'moderate');
    });

    test('alcohol going true is an event; staying true is not', () {
      final tracker = RtdbHelmetTracker();
      tracker.observe('tracker-001', device: device('Monitoring', 3000000));
      tracker.observe(
        'tracker-001',
        device: device('Alcohol threshold exceeded', 3010000, alcohol: true),
      );
      tracker.observe(
        'tracker-001',
        device: device('Alcohol threshold exceeded', 3020000, alcohol: true),
      );
      final event = tracker.events.single;
      expect(event.kind, HelmetEventKind.alcohol);
      expect(event.detail, contains('raw 934'));
      expect(event.detail, contains('threshold 900'));
      expect(event.detail, isNot(contains('mg')));
    });

    test('every gpsLogs entry is an emergency upload, and covers the crash', () {
      final tracker = RtdbHelmetTracker();
      tracker.observe(
        'tracker-001',
        device: device('Crash alert: abnormal posture persisted 12 minutes', 4000000),
        gpsLogs: {
          '-a': {
            'lat': 14.31,
            'lng': 121.13,
            'satellites': 7,
            'reason': 'suspected-crash',
            'serverTime': 4030000,
          },
        },
      );
      // One incident, kept as the upload, which has the position.
      final event = tracker.events.single;
      expect(event.kind, HelmetEventKind.emergencyUpload);
      expect(event.id, 'tracker-001_4030000');
      expect(event.detail, 'suspected-crash');
      expect(event.lat, 14.31);
    });

    test('remembers when the vibration switch last changed', () {
      final tracker = RtdbHelmetTracker();
      Map<Object?, Object?> safety(bool active, int at) => {
        'safety': {'sw420Active': active, 'serverTime': at},
      };
      tracker.observe('tracker-001', device: safety(false, 5000000));
      expect(tracker.sw420ChangedAt('tracker-001'), isNull);
      tracker.observe('tracker-001', device: safety(false, 5010000));
      expect(tracker.sw420ChangedAt('tracker-001'), isNull);
      tracker.observe('tracker-001', device: safety(true, 5020000));
      expect(tracker.sw420ChangedAt('tracker-001'), _ms(5020000));
      tracker.observe('tracker-001', device: safety(true, 5030000));
      expect(tracker.sw420ChangedAt('tracker-001'), _ms(5020000));
    });
  });
}
