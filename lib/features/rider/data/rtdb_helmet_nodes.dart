/// Turns the helmet's Realtime Database nodes into one [HelmetTelemetry].
///
/// The firmware (IoT/NovaRide/…Integrated, `USE_FIRESTORE 0`) does not
/// write one node. It writes several, at different rates, and only some of
/// them carry a position:
///
/// | Node                         | Every     | Sensors | Position | Speed |
/// |------------------------------|-----------|---------|----------|-------|
/// | `deviceStatus/{id}`          | 30 s      | yes     | yes¹     | yes¹  |
/// | `devices/{id}/safety`        | 10 s      | yes     | –        | –     |
/// | `devices/{id}/tracking`      | 5 min²    | yes     | yes      | –     |
/// | `devices/{id}/latest`        | on alerts | yes     | yes      | yes   |
/// | `trackingLogs/{id}/{push}`   | 5 min²    | yes     | yes      | –     |
/// | `gpsLogs/{id}/{push}`        | on alerts | yes     | yes      | yes   |
///
/// ¹ Only with the firmware change that adds the last GPS fix to the
///   status heartbeat; older firmware sends no position there.
/// ² Only when the GPS has a fix under 30 s old.
///
/// So the merge is:
///
/// * **Sensors** from whichever of `deviceStatus` and `devices/{id}/safety`
///   was written last. Safety sends x/y/z rather than a magnitude, so the
///   magnitude is computed from them.
/// * **Position** from the newest *real* one across every node that has
///   one. "Real" excludes what a GPS module reports before it has locked:
///   zero satellites, or a latitude or longitude of exactly 0 (the live
///   database has `lat: 0, lng: 0.366667` in it, which is not a place).
/// * **Speed** only from the node the position came from — a speed is
///   only meaningful with its own fix. Whether it is *current* is the
///   entity's call ([HelmetTelemetry.currentSpeedKmph]).
/// * **Last seen** is the newest write of any kind, so a helmet still
///   sending safety readings every 10 s is not called stale because its
///   30 s heartbeat is late.
library;

import 'dart:math' as math;

import '../domain/entities/helmet_telemetry.dart';

/// Everything one listener can see. Each argument is the raw
/// `snapshot.value` of its node (or null for "nothing there").
HelmetTelemetry? mergeHelmetNodes({
  Object? status,
  Object? device,
  Object? trackingLogs,
  Object? gpsLogs,
}) {
  final statusMap = _map(status);
  final deviceMap = _map(device);
  final latest = _map(deviceMap?['latest']);
  final tracking = _map(deviceMap?['tracking']);
  final safety = _map(deviceMap?['safety']);
  final logs = [
    ..._entries(trackingLogs),
    ..._entries(gpsLogs),
  ];

  if (statusMap == null &&
      latest == null &&
      tracking == null &&
      safety == null &&
      logs.isEmpty) {
    return null; // the helmet has never written anything at this id
  }

  final statusT = statusMap == null ? null : HelmetTelemetry.fromMap(statusMap);
  final statusAt = statusT?.lastSeen;
  final safetyAt = _epochMs(safety?['serverTime']);

  // ------------------------------------------------------------- sensors
  final _Sensors sensors;
  if (safety != null &&
      safetyAt != null &&
      (statusAt == null || safetyAt.isAfter(statusAt))) {
    sensors = _Sensors.fromSafety(safety);
  } else if (statusT != null) {
    sensors = _Sensors.fromTelemetry(statusT);
  } else {
    // No heartbeat yet: fall back to the readings that rode along with
    // whichever position node exists.
    final any = latest ?? tracking ?? (logs.isEmpty ? null : logs.last);
    sensors = any == null
        ? const _Sensors()
        : _Sensors.fromTelemetry(HelmetTelemetry.fromMap(any));
  }

  // ------------------------------------------------------------ position
  final candidates = <_Position>[
    if (statusMap != null) ?_Position.from(statusMap, timeKey: 'lastSeen'),
    if (latest != null) ?_Position.from(latest),
    if (tracking != null) ?_Position.from(tracking),
    for (final entry in logs) ?_Position.from(entry),
  ];
  _Position? position;
  for (final c in candidates) {
    if (position == null || c.takenAt.isAfter(position.takenAt)) position = c;
  }

  // ----------------------------------------------------------- last seen
  DateTime? lastSeen = statusAt;
  for (final t in [
    safetyAt,
    _epochMs(tracking?['serverTime']),
    _epochMs(latest?['serverTime']),
  ]) {
    if (t != null && (lastSeen == null || t.isAfter(lastSeen))) lastSeen = t;
  }

  return HelmetTelemetry(
    deviceId: statusT?.deviceId ?? _string(latest?['deviceId']) ?? _string(safety?['deviceId']),
    online: statusT?.online,
    lastSeen: lastSeen,
    ip: statusT?.ip,
    cellularDataReady: statusT?.cellularDataReady,
    accelerometerReady: sensors.accelerometerReady,
    accelMagnitudeG: sensors.accelMagnitudeG,
    sw420Active: sensors.sw420Active,
    tiltDegrees: sensors.tiltDegrees,
    orientation: sensors.orientation,
    safetyEvent: sensors.safetyEvent,
    mq3Raw: sensors.mq3Raw,
    mq3Voltage: sensors.mq3Voltage,
    alcoholRelativeIndex: sensors.alcoholRelativeIndex,
    alcoholAlert: sensors.alcoholAlert,
    gpsNmeaChars: statusT?.gpsNmeaChars,
    gpsValidSentences: statusT?.gpsValidSentences,
    lat: position?.lat,
    lng: position?.lng,
    speedKmph: position?.speedKmph,
    altitudeM: position?.altitudeM,
    satellites: position?.satellites,
    gpsAgeMs: position?.gpsAgeMs,
    mapsUrl: position?.mapsUrl,
    fixAt: position?.takenAt,
  );
}

/// The sensor readings, from one node.
class _Sensors {
  const _Sensors({
    this.accelerometerReady,
    this.accelMagnitudeG,
    this.sw420Active,
    this.tiltDegrees,
    this.orientation,
    this.safetyEvent,
    this.mq3Raw,
    this.mq3Voltage,
    this.alcoholRelativeIndex,
    this.alcoholAlert,
  });

  factory _Sensors.fromTelemetry(HelmetTelemetry t) => _Sensors(
        accelerometerReady: t.accelerometerReady,
        accelMagnitudeG: t.accelMagnitudeG,
        sw420Active: t.sw420Active,
        tiltDegrees: t.tiltDegrees,
        orientation: t.orientation,
        safetyEvent: t.safetyEvent,
        mq3Raw: t.mq3Raw,
        mq3Voltage: t.mq3Voltage,
        alcoholRelativeIndex: t.alcoholRelativeIndex,
        alcoholAlert: t.alcoholAlert,
      );

  /// `devices/{id}/safety` names two fields differently (`mpuReady`, and
  /// x/y/z instead of a magnitude).
  factory _Sensors.fromSafety(Map<Object?, Object?> m) {
    final t = HelmetTelemetry.fromMap(m);
    final x = _double(m['xG']), y = _double(m['yG']), z = _double(m['zG']);
    final ready = _bool(m['mpuReady']);
    return _Sensors(
      accelerometerReady: ready,
      accelMagnitudeG: (ready == false || x == null || y == null || z == null)
          ? null
          : math.sqrt(x * x + y * y + z * z),
      sw420Active: t.sw420Active,
      tiltDegrees: t.tiltDegrees,
      orientation: t.orientation,
      safetyEvent: t.safetyEvent,
      mq3Raw: t.mq3Raw,
      mq3Voltage: t.mq3Voltage,
      alcoholRelativeIndex: t.alcoholRelativeIndex,
      alcoholAlert: t.alcoholAlert,
    );
  }

  final bool? accelerometerReady;
  final double? accelMagnitudeG;
  final bool? sw420Active;
  final double? tiltDegrees;
  final String? orientation;
  final String? safetyEvent;
  final int? mq3Raw;
  final double? mq3Voltage;
  final double? alcoholRelativeIndex;
  final bool? alcoholAlert;
}

/// One real position, and when it was taken.
class _Position {
  const _Position({
    required this.lat,
    required this.lng,
    required this.takenAt,
    this.speedKmph,
    this.altitudeM,
    this.satellites,
    this.gpsAgeMs,
    this.mapsUrl,
  });

  final double lat;
  final double lng;
  final DateTime takenAt;
  final double? speedKmph;
  final double? altitudeM;
  final int? satellites;
  final int? gpsAgeMs;
  final String? mapsUrl;

  /// Null when [m] has no position, a pre-lock one, or no time to place it
  /// by. [timeKey] is the server-time field: `serverTime` on every node
  /// but `deviceStatus`, which uses `lastSeen`.
  static _Position? from(Map<Object?, Object?> m, {String timeKey = 'serverTime'}) {
    final lat = _double(m['lat']);
    final lng = _double(m['lng']);
    final written = _epochMs(m[timeKey]);
    if (lat == null || lng == null || written == null) return null;
    if (lat == 0 || lng == 0 || lat.abs() > 90 || lng.abs() > 180) return null;
    final satellites = _int(m['satellites']);
    if (satellites == 0) return null;
    // gpsAgeMs is "how old the fix was when written".
    final age = _int(m['gpsAgeMs']);
    return _Position(
      lat: lat,
      lng: lng,
      takenAt: age == null ? written : written.subtract(Duration(milliseconds: age)),
      speedKmph: _double(m['speedKmph']),
      altitudeM: _double(m['altitudeM']),
      satellites: satellites,
      gpsAgeMs: age,
      mapsUrl: _string(m['mapsUrl']),
    );
  }
}

// ----------------------------------------------------------------- parsing

Map<Object?, Object?>? _map(Object? v) => v is Map<Object?, Object?> ? v : null;

/// The child maps of a `…Logs/{id}` node, in push-id (time) order. RTDB
/// may hand a push-keyed node back as a Map or, rarely, a List.
List<Map<Object?, Object?>> _entries(Object? v) {
  if (v is Map<Object?, Object?>) {
    final keys = v.keys.whereType<String>().toList()..sort();
    return [for (final k in keys) ?_map(v[k])];
  }
  if (v is List<Object?>) return [for (final e in v) ?_map(e)];
  return const [];
}

double? _double(Object? v) => v is num ? v.toDouble() : null;
bool? _bool(Object? v) => v is bool ? v : null;
String? _string(Object? v) => v is String ? v : null;

int? _int(Object? v) {
  if (v is int) return v;
  if (v is double && v == v.truncateToDouble()) return v.toInt();
  return null;
}

DateTime? _epochMs(Object? v) {
  final ms = _int(v);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
