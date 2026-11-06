/// Turns one helmet's Realtime Database nodes into the console's
/// [HelmetTelemetry], its fix history, and the events it reported.
///
/// A port of the rider app's merge (`lib/features/rider/data/
/// rtdb_helmet_nodes.dart`, `mergeHelmetNodes`) — copied, not imported: the
/// admin module never imports from `lib/features/` (docs/ADMIN_MODULE.md).
/// If the firmware's node layout changes, both files change together; the
/// test fixtures in `test/rtdb_fleet_merge_test.dart` are the rider app's,
/// so a drift between the two shows up as a failing test.
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
///   magnitude is computed from them. One addition over the rider app: a
///   field the winning node does not carry at all is taken from the other
///   node. The two nodes carry different field sets — only safety has
///   `alcoholThreshold` and, on this firmware, `safetyEvent`; only the
///   heartbeat has `ip` and the NMEA counters — so without this the safety
///   event would blank out for 10 s every time the heartbeat landed. A
///   field is never invented: it is the other node's real, slightly older
///   reading, and the label shows "—" only when neither node has it.
/// * **Position** from the newest *real* one across every node that has
///   one. "Real" excludes what a GPS module reports before it has locked:
///   zero satellites, or a latitude or longitude of exactly 0 (the live
///   database has `lat: 0, lng: 0.366667` in it, which is not a place).
///   Fix time is the node's server time (`serverTime`, or `lastSeen` on
///   the heartbeat) minus `gpsAgeMs`, the fix's age when written.
/// * **Speed** only from the node the position came from — a speed is
///   only meaningful with its own fix — and only while that fix is current
///   ([kFixCurrentFor]).
/// * **Last seen** is the newest write of any kind, so a helmet still
///   sending safety readings every 10 s is not called stale because its
///   30 s heartbeat is late.
///
/// Parsing is strict on type and forgiving on records: a value of the wrong
/// type is absent, never coerced, and a log entry that cannot be read is
/// skipped without taking the rest of the helmet down with it.
library;

import 'dart:math' as math;

import 'package:novaride/admin/data/fleet_geography.dart' show isRealPosition;
import 'package:novaride/shared/models/models.dart';

/// How long a fix still counts as current — for speed, the GPS "Locked"
/// readout and the map's stale badge. The firmware uploads its location
/// every 5 min (`PERIODIC_LOCATION_UPLOAD_INTERVAL_MS`) and a cellular
/// upload may take 90 s to land, so 7 min.
const Duration kFixCurrentFor = Duration(minutes: 7);

/// A fix older than this when written is not usable: the firmware's own
/// `GPS_FIX_TIMEOUT_MS`.
const int kUsableFixAgeMs = 30000;

/// How many entries of `trackingLogs/{id}` and `gpsLogs/{id}` the console
/// listens to, per helmet. Both roots grow forever; listening to either
/// whole would download every fix the fleet ever sent.
const int kLogEntriesPerDevice = 10;

/// Merges one helmet's nodes. Each argument is the raw `snapshot.value` of
/// its node (or null for "nothing there"); [device] is `devices/{id}`, with
/// its `latest`, `tracking` and `safety` children.
///
/// Returns null when the helmet has never written anything at this id.
/// [riderId] is the roster join, done by the caller. [sw420ChangedAt] comes
/// from [RtdbHelmetTracker], which remembers values across snapshots.
HelmetTelemetry? mergeFleetNodes({
  required String deviceId,
  String? riderId,
  Object? status,
  Object? device,
  Object? trackingLogs,
  Object? gpsLogs,
  required DateTime now,
  DateTime? sw420ChangedAt,
}) {
  final statusMap = _map(status);
  final deviceMap = _map(device);
  final latest = _map(deviceMap?['latest']);
  final tracking = _map(deviceMap?['tracking']);
  final safety = _map(deviceMap?['safety']);
  final tLogs = logEntries(trackingLogs);
  final gLogs = logEntries(gpsLogs);

  if (statusMap == null &&
      latest == null &&
      tracking == null &&
      safety == null &&
      tLogs.isEmpty &&
      gLogs.isEmpty) {
    return null;
  }

  final statusAt = _epochMs(statusMap?['lastSeen']);
  final safetyAt = _epochMs(safety?['serverTime']);

  // ------------------------------------------------------------- sensors
  final fromStatus = statusMap == null ? null : _Sensors.fromStatus(statusMap);
  final fromSafety = safety == null ? null : _Sensors.fromSafety(safety);
  final _Sensors sensors;
  if (fromSafety != null &&
      safetyAt != null &&
      (statusAt == null || safetyAt.isAfter(statusAt))) {
    sensors = fromSafety.orElse(fromStatus);
  } else if (fromStatus != null) {
    sensors = fromStatus.orElse(fromSafety);
  } else {
    // No heartbeat and no safety node: fall back to the readings that rode
    // along with whichever position node exists.
    final any =
        latest ??
        tracking ??
        (gLogs.isNotEmpty ? gLogs.last.value : null) ??
        (tLogs.isNotEmpty ? tLogs.last.value : null);
    sensors = any == null ? const _Sensors() : _Sensors.fromStatus(any);
  }

  // ------------------------------------------------------------ position
  final position = _newest([
    if (statusMap != null)
      ?_Position.from(
        statusMap,
        timeKey: 'lastSeen',
        source: PositionSource.deviceStatus,
      ),
    if (latest != null) ?_Position.from(latest, source: PositionSource.latest),
    if (tracking != null)
      ?_Position.from(tracking, source: PositionSource.tracking),
    for (final e in tLogs)
      ?_Position.from(e.value, source: PositionSource.trackingLogs),
    for (final e in gLogs)
      ?_Position.from(e.value, source: PositionSource.gpsLogs),
  ]);

  // ----------------------------------------------------------- last seen
  DateTime? lastSeen = statusAt;
  for (final t in [
    safetyAt,
    _epochMs(tracking?['serverTime']),
    _epochMs(latest?['serverTime']),
    for (final e in tLogs) _epochMs(e.value['serverTime']),
    for (final e in gLogs) _epochMs(e.value['serverTime']),
  ]) {
    if (t != null && (lastSeen == null || t.isAfter(lastSeen))) lastSeen = t;
  }

  final current = position != null && position.isCurrent(now);

  return HelmetTelemetry(
    riderId: riderId,
    deviceId: deviceId,
    speedKmh: current ? position.speedKmph : null,
    alcoholDetected: sensors.alcoholAlert,
    alcoholRawIndex: sensors.alcoholRelativeIndex,
    accelMagnitudeG: sensors.accelerometerReady == false
        ? null
        : sensors.accelMagnitudeG,
    // The RTDB firmware sends no battery reading at all.
    batteryPct: null,
    gpsFix: current,
    lat: position?.lat,
    lng: position?.lng,
    lastUpdate: lastSeen,
    lastSeen: lastSeen,
    online: _bool(statusMap?['online']),
    ip: _string(statusMap?['ip']),
    cellularDataReady: _bool(statusMap?['cellularDataReady']),
    gpsNmeaChars: _int(statusMap?['gpsNmeaChars']),
    gpsValidSentences: _int(statusMap?['gpsValidSentences']),
    sw420Active: sensors.sw420Active,
    sw420ChangedAt: sw420ChangedAt,
    tiltDegrees: sensors.tiltDegrees,
    orientation: sensors.orientation,
    safetyEvent: sensors.safetyEvent,
    mq3Raw: sensors.mq3Raw,
    mq3Voltage: sensors.mq3Voltage,
    alcoholThreshold: sensors.alcoholThreshold,
    accelerometerReady: sensors.accelerometerReady,
    accelXG: sensors.accelerometerReady == false ? null : sensors.xG,
    accelYG: sensors.accelerometerReady == false ? null : sensors.yG,
    accelZG: sensors.accelerometerReady == false ? null : sensors.zG,
    satellites: position?.satellites,
    altitudeM: position?.altitudeM,
    gpsAgeMs: position?.gpsAgeMs,
    fixAt: position?.takenAt,
    mapsUrl: position?.mapsUrl,
    positionSource: position?.source,
  );
}

/// Every real fix in a helmet's nodes, oldest first, de-duplicated — the
/// seed for the breadcrumb trail and the lookup for an alert that arrived
/// with no position of its own.
///
/// The same upload lands in two places (`devices/{id}/tracking` and a
/// `trackingLogs` entry, with server times a few milliseconds apart), so a
/// fix at the same coordinates within [_sameFixWindow] of the previous one
/// is dropped.
List<HelmetFix> fixHistoryFromNodes({
  Object? status,
  Object? device,
  Object? trackingLogs,
  Object? gpsLogs,
}) {
  final statusMap = _map(status);
  final deviceMap = _map(device);
  final latest = _map(deviceMap?['latest']);
  final tracking = _map(deviceMap?['tracking']);
  final all = <_Position>[
    if (statusMap != null)
      ?_Position.from(
        statusMap,
        timeKey: 'lastSeen',
        source: PositionSource.deviceStatus,
      ),
    if (latest != null) ?_Position.from(latest, source: PositionSource.latest),
    if (tracking != null)
      ?_Position.from(tracking, source: PositionSource.tracking),
    for (final e in logEntries(trackingLogs))
      ?_Position.from(e.value, source: PositionSource.trackingLogs),
    for (final e in logEntries(gpsLogs))
      ?_Position.from(e.value, source: PositionSource.gpsLogs),
  ]..sort((a, b) => a.takenAt.compareTo(b.takenAt));

  final out = <HelmetFix>[];
  for (final p in all) {
    if (out.isNotEmpty) {
      final last = out.last;
      if (last.lat == p.lat &&
          last.lng == p.lng &&
          p.takenAt.difference(last.at).abs() <= _sameFixWindow) {
        continue;
      }
    }
    out.add(p.toFix());
  }
  return out;
}

const Duration _sameFixWindow = Duration(seconds: 30);

/// The newest fix in [fixes] (oldest first) taken at or before [at], or
/// null if there is none.
HelmetFix? lastFixAtOrBefore(List<HelmetFix> fixes, DateTime at) {
  HelmetFix? best;
  for (final f in fixes) {
    if (f.at.isAfter(at)) continue;
    if (best == null || f.at.isAfter(best.at)) best = f;
  }
  return best;
}

/// The child maps of a `…Logs/{id}` node, in push-id (time) order, with
/// their keys. RTDB may hand a push-keyed node back as a Map or, rarely, a
/// List; anything that is not a map is skipped.
List<MapEntry<String, Map<Object?, Object?>>> logEntries(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return [
      for (final k in keys)
        if (_map(v[k]) case final m?) MapEntry(k, m),
    ];
  }
  if (v is List) {
    return [
      for (var i = 0; i < v.length; i++)
        if (_map(v[i]) case final m?) MapEntry('$i', m),
    ];
  }
  return const [];
}

// ---------------------------------------------------------------- tracker

/// The part of the RTDB reading that needs memory: what the helmet
/// *reported happening* (crash and rider-check states, alcohol verdicts,
/// emergency uploads) and when the vibration switch last changed.
///
/// Realtime Database nodes are overwritten in place, so a transition is only
/// visible by comparing one snapshot with the previous one. The repository
/// feeds every snapshot of a helmet through [observe] and reads [events]
/// and [sw420ChangedAt] back.
///
/// Event ids are `{deviceId}_{serverTimeMs}` of the write that carried the
/// event, so every console watching at the time derives the same id — and
/// "Open as alert" creates the Firestore alert under that id, so two
/// consoles cannot create it twice.
///
/// A console that starts while a helmet is already in a crash or alcohol
/// state did not see the transition, but the state is real and active: it
/// is reported once, at the first write this console saw, and not again
/// until the state clears and returns.
class RtdbHelmetTracker {
  /// Events kept, newest first. Older ones age off.
  static const maxEvents = 50;

  /// A second alcohol event for the same helmet inside this window is the
  /// same episode flickering around the threshold, not a new one.
  static const alcoholCooldown = Duration(minutes: 5);

  /// A safety-node crash and a `gpsLogs` emergency upload this close
  /// together are one incident; the upload, which carries the position, is
  /// the one kept.
  static const sameIncidentWindow = Duration(minutes: 5);

  final Map<String, HelmetEventKind> _activeSafety = {};
  final Map<String, bool> _alcohol = {};
  final Map<String, DateTime> _lastAlcoholEvent = {};
  final Map<String, ({bool value, DateTime? changedAt})> _sw420 = {};
  final Map<String, HelmetEvent> _events = {};

  /// Feeds one helmet's current nodes. Returns true if [events] changed.
  bool observe(
    String deviceId, {
    Object? status,
    Object? device,
    Object? trackingLogs,
    Object? gpsLogs,
  }) {
    final before = _events.length;
    final statusMap = _map(status);
    final safety = _map(_map(device)?['safety']);
    final statusAt = _epochMs(statusMap?['lastSeen']);
    final safetyAt = _epochMs(safety?['serverTime']);

    // Same winner rule as the merge, field by field.
    final safetyWins =
        safety != null &&
        safetyAt != null &&
        (statusAt == null || safetyAt.isAfter(statusAt));
    final first = safetyWins ? safety : statusMap;
    final second = safetyWins ? statusMap : safety;
    final firstAt = safetyWins ? safetyAt : statusAt;
    final secondAt = safetyWins ? statusAt : safetyAt;

    String? safetyEvent = _string(first?['safetyEvent']);
    DateTime? safetyEventAt = firstAt;
    if (safetyEvent == null) {
      safetyEvent = _string(second?['safetyEvent']);
      safetyEventAt = secondAt;
    }
    bool? alcoholAlert = _bool(first?['alcoholAlert']);
    DateTime? alcoholAt = firstAt;
    if (alcoholAlert == null) {
      alcoholAlert = _bool(second?['alcoholAlert']);
      alcoholAt = secondAt;
    }
    final position = _Position.from(
      statusMap ?? const {},
      timeKey: 'lastSeen',
      source: PositionSource.deviceStatus,
    );

    // ---------------------------------------------- crash / rider check
    final kind = _safetyKind(safetyEvent);
    if (kind == null) {
      _activeSafety.remove(deviceId);
    } else if (_activeSafety[deviceId] != kind && safetyEventAt != null) {
      _activeSafety[deviceId] = kind;
      _add(
        HelmetEvent(
          id: helmetEventId(deviceId, safetyEventAt),
          deviceId: deviceId,
          kind: kind,
          at: safetyEventAt,
          detail: safetyEvent!,
          lat: position?.lat,
          lng: position?.lng,
        ),
      );
    }

    // ------------------------------------------------------- alcohol
    if (alcoholAlert != null) {
      final was = _alcohol[deviceId];
      _alcohol[deviceId] = alcoholAlert;
      final last = _lastAlcoholEvent[deviceId];
      if (alcoholAlert &&
          was != true &&
          alcoholAt != null &&
          (last == null || alcoholAt.difference(last) > alcoholCooldown)) {
        _lastAlcoholEvent[deviceId] = alcoholAt;
        final raw = _double(first?['alcoholRelativeIndex']);
        final threshold =
            _double(safety?['alcoholThreshold']) ??
            _double(statusMap?['alcoholThreshold']);
        _add(
          HelmetEvent(
            id: helmetEventId(deviceId, alcoholAt),
            deviceId: deviceId,
            kind: HelmetEventKind.alcohol,
            at: alcoholAt,
            detail: [
              'Alcohol threshold exceeded',
              if (raw != null) 'raw ${raw.toStringAsFixed(0)}',
              if (threshold != null) 'threshold ${threshold.toStringAsFixed(0)}',
            ].join(' · '),
            lat: position?.lat,
            lng: position?.lng,
          ),
        );
      }
    }

    // -------------------------------------------- emergency uploads
    for (final entry in logEntries(gpsLogs)) {
      final at = _epochMs(entry.value['serverTime']);
      if (at == null) continue;
      final p = _Position.from(entry.value, source: PositionSource.gpsLogs);
      _add(
        HelmetEvent(
          id: helmetEventId(deviceId, at),
          deviceId: deviceId,
          kind: HelmetEventKind.emergencyUpload,
          at: at,
          detail: _string(entry.value['reason']) ?? 'emergency upload',
          lat: p?.lat,
          lng: p?.lng,
        ),
      );
    }

    // ---------------------------------------------------- vibration
    _trackSw420(
      deviceId,
      status: statusMap,
      safety: safety,
      device: _map(device),
      trackingLogs: trackingLogs,
      gpsLogs: gpsLogs,
    );

    return _events.length != before;
  }

  /// When the SW-420 last changed state, as far as this console has seen.
  DateTime? sw420ChangedAt(String deviceId) => _sw420[deviceId]?.changedAt;

  /// Newest first, capped at [maxEvents], with a safety-node crash hidden
  /// when an emergency upload from the same helmet covers the same incident.
  List<HelmetEvent> get events {
    final all = _events.values.toList()..sort((a, b) => b.at.compareTo(a.at));
    final uploads = [
      for (final e in all)
        if (e.kind == HelmetEventKind.emergencyUpload) e,
    ];
    final kept = [
      for (final e in all)
        if (e.kind != HelmetEventKind.crash ||
            !uploads.any(
              (u) =>
                  u.deviceId == e.deviceId &&
                  u.at.difference(e.at).abs() <= sameIncidentWindow,
            ))
          e,
    ];
    return kept.length > maxEvents ? kept.sublist(0, maxEvents) : kept;
  }

  /// Forgets a helmet that has disappeared from the database.
  void forget(String deviceId) {
    _activeSafety.remove(deviceId);
    _alcohol.remove(deviceId);
    _lastAlcoholEvent.remove(deviceId);
    _sw420.remove(deviceId);
  }

  void _add(HelmetEvent event) {
    _events.putIfAbsent(event.id, () => event);
    if (_events.length > maxEvents * 2) {
      final oldest = _events.values.toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      for (final e in oldest.take(_events.length - maxEvents)) {
        _events.remove(e.id);
      }
    }
  }

  /// The current SW-420 value and when it last changed. Across snapshots
  /// the comparison is with the previous value this console saw; on the
  /// first snapshot, with the readings the logs and position nodes carry.
  void _trackSw420(
    String deviceId, {
    Map<Object?, Object?>? status,
    Map<Object?, Object?>? safety,
    Map<Object?, Object?>? device,
    Object? trackingLogs,
    Object? gpsLogs,
  }) {
    final observations = <({DateTime at, bool value})>[
      ?_obs(status, 'lastSeen'),
      ?_obs(safety, 'serverTime'),
      ?_obs(_map(device?['latest']), 'serverTime'),
      ?_obs(_map(device?['tracking']), 'serverTime'),
      for (final e in logEntries(trackingLogs)) ?_obs(e.value, 'serverTime'),
      for (final e in logEntries(gpsLogs)) ?_obs(e.value, 'serverTime'),
    ]..sort((a, b) => a.at.compareTo(b.at));
    if (observations.isEmpty) return;
    final current = observations.last;

    final previous = _sw420[deviceId];
    if (previous != null) {
      if (previous.value != current.value) {
        _sw420[deviceId] = (value: current.value, changedAt: current.at);
      }
      return;
    }
    // First sight: the last change visible in the history, if any.
    DateTime? changedAt;
    for (var i = observations.length - 1; i > 0; i--) {
      if (observations[i - 1].value != observations[i].value) {
        changedAt = observations[i].at;
        break;
      }
    }
    _sw420[deviceId] = (value: current.value, changedAt: changedAt);
  }

  static ({DateTime at, bool value})? _obs(
    Map<Object?, Object?>? m,
    String timeKey,
  ) {
    final at = _epochMs(m?[timeKey]);
    final value = _bool(m?['sw420Active']);
    return at == null || value == null ? null : (at: at, value: value);
  }

  static HelmetEventKind? _safetyKind(String? safetyEvent) {
    final s = (safetyEvent ?? '').toLowerCase();
    if (s.startsWith('crash alert')) return HelmetEventKind.crash;
    if (s.startsWith('rider check alert')) return HelmetEventKind.riderCheck;
    return null;
  }
}

/// `{deviceId}_{serverTimeMs}` — the event's id and the alert id it opens
/// as. Firestore document ids may not contain `/`, and RTDB keys cannot, so
/// the device id is safe as is.
String helmetEventId(String deviceId, DateTime at) =>
    '${deviceId}_${at.millisecondsSinceEpoch}';

// ----------------------------------------------------------------- pieces

/// The sensor readings, from one node.
class _Sensors {
  const _Sensors({
    this.accelerometerReady,
    this.accelMagnitudeG,
    this.xG,
    this.yG,
    this.zG,
    this.sw420Active,
    this.tiltDegrees,
    this.orientation,
    this.safetyEvent,
    this.mq3Raw,
    this.mq3Voltage,
    this.alcoholRelativeIndex,
    this.alcoholThreshold,
    this.alcoholAlert,
  });

  /// `deviceStatus/{id}`, and the position nodes, which use the heartbeat's
  /// names (`accelerometerReady`, `accelXG`…; tracking uses `xG`…).
  factory _Sensors.fromStatus(Map<Object?, Object?> m) => _Sensors(
    accelerometerReady: _bool(m['accelerometerReady']),
    accelMagnitudeG: _double(m['accelMagnitudeG']),
    xG: _double(m['accelXG']) ?? _double(m['xG']),
    yG: _double(m['accelYG']) ?? _double(m['yG']),
    zG: _double(m['accelZG']) ?? _double(m['zG']),
    sw420Active: _bool(m['sw420Active']),
    tiltDegrees: _double(m['tiltDegrees']),
    orientation: _string(m['orientation']),
    safetyEvent: _string(m['safetyEvent']),
    mq3Raw: _int(m['mq3Raw']),
    mq3Voltage: _double(m['mq3Voltage']),
    alcoholRelativeIndex: _double(m['alcoholRelativeIndex']),
    alcoholThreshold: _double(m['alcoholThreshold']),
    alcoholAlert: _bool(m['alcoholAlert']),
  );

  /// `devices/{id}/safety` names two fields differently (`mpuReady`, and
  /// x/y/z instead of a magnitude).
  factory _Sensors.fromSafety(Map<Object?, Object?> m) {
    final x = _double(m['xG']), y = _double(m['yG']), z = _double(m['zG']);
    final ready = _bool(m['mpuReady']);
    return _Sensors(
      accelerometerReady: ready,
      accelMagnitudeG: (ready == false || x == null || y == null || z == null)
          ? null
          : math.sqrt(x * x + y * y + z * z),
      xG: x,
      yG: y,
      zG: z,
      sw420Active: _bool(m['sw420Active']),
      tiltDegrees: _double(m['tiltDegrees']),
      orientation: _string(m['orientation']),
      safetyEvent: _string(m['safetyEvent']),
      mq3Raw: _int(m['mq3Raw']),
      mq3Voltage: _double(m['mq3Voltage']),
      alcoholRelativeIndex: _double(m['alcoholRelativeIndex']),
      alcoholThreshold: _double(m['alcoholThreshold']),
      alcoholAlert: _bool(m['alcoholAlert']),
    );
  }

  /// These readings, with anything this node did not carry taken from
  /// [other]. See the library comment.
  _Sensors orElse(_Sensors? other) {
    if (other == null) return this;
    return _Sensors(
      accelerometerReady: accelerometerReady ?? other.accelerometerReady,
      accelMagnitudeG: accelMagnitudeG ?? other.accelMagnitudeG,
      xG: xG ?? other.xG,
      yG: yG ?? other.yG,
      zG: zG ?? other.zG,
      sw420Active: sw420Active ?? other.sw420Active,
      tiltDegrees: tiltDegrees ?? other.tiltDegrees,
      orientation: orientation ?? other.orientation,
      safetyEvent: safetyEvent ?? other.safetyEvent,
      mq3Raw: mq3Raw ?? other.mq3Raw,
      mq3Voltage: mq3Voltage ?? other.mq3Voltage,
      alcoholRelativeIndex: alcoholRelativeIndex ?? other.alcoholRelativeIndex,
      alcoholThreshold: alcoholThreshold ?? other.alcoholThreshold,
      alcoholAlert: alcoholAlert ?? other.alcoholAlert,
    );
  }

  final bool? accelerometerReady;
  final double? accelMagnitudeG;
  final double? xG;
  final double? yG;
  final double? zG;
  final bool? sw420Active;
  final double? tiltDegrees;
  final String? orientation;
  final String? safetyEvent;
  final int? mq3Raw;
  final double? mq3Voltage;
  final double? alcoholRelativeIndex;
  final double? alcoholThreshold;
  final bool? alcoholAlert;
}

/// One real position, and when it was taken.
class _Position {
  const _Position({
    required this.lat,
    required this.lng,
    required this.takenAt,
    required this.source,
    this.speedKmph,
    this.altitudeM,
    this.satellites,
    this.gpsAgeMs,
    this.mapsUrl,
    this.reason,
  });

  final double lat;
  final double lng;
  final DateTime takenAt;
  final PositionSource source;
  final double? speedKmph;
  final double? altitudeM;
  final int? satellites;
  final int? gpsAgeMs;
  final String? mapsUrl;
  final String? reason;

  /// Usable when written (not already older than [kUsableFixAgeMs]) and
  /// taken within [kFixCurrentFor] of [now].
  bool isCurrent(DateTime now) {
    final age = gpsAgeMs;
    if (age != null && age > kUsableFixAgeMs) return false;
    return now.difference(takenAt) <= kFixCurrentFor;
  }

  HelmetFix toFix() => HelmetFix(
    lat: lat,
    lng: lng,
    at: takenAt,
    source: source,
    speedKmph: speedKmph,
    reason: reason,
  );

  /// Null when [m] has no position, a pre-lock one, or no time to place it
  /// by. [timeKey] is the server-time field: `serverTime` on every node
  /// but `deviceStatus`, which uses `lastSeen`.
  static _Position? from(
    Map<Object?, Object?> m, {
    String timeKey = 'serverTime',
    required PositionSource source,
  }) {
    final lat = _double(m['lat']);
    final lng = _double(m['lng']);
    final written = _epochMs(m[timeKey]);
    if (written == null || !isRealPosition(lat, lng)) return null;
    final satellites = _int(m['satellites']);
    if (satellites == 0) return null;
    // gpsAgeMs is "how old the fix was when written".
    final age = _int(m['gpsAgeMs']);
    return _Position(
      lat: lat!,
      lng: lng!,
      takenAt: age == null
          ? written
          : written.subtract(Duration(milliseconds: age)),
      source: source,
      speedKmph: _double(m['speedKmph']),
      altitudeM: _double(m['altitudeM']),
      satellites: satellites,
      gpsAgeMs: age,
      mapsUrl: _string(m['mapsUrl']),
      reason: _string(m['reason']),
    );
  }
}

_Position? _newest(List<_Position> candidates) {
  _Position? best;
  for (final c in candidates) {
    if (best == null || c.takenAt.isAfter(best.takenAt)) best = c;
  }
  return best;
}

// ----------------------------------------------------------------- parsing

Map<Object?, Object?>? _map(Object? v) =>
    v is Map ? {for (final e in v.entries) e.key: e.value} : null;

double? _double(Object? v) => v is num ? v.toDouble() : null;
bool? _bool(Object? v) => v is bool ? v : null;
String? _string(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

/// Realtime Database hands back 512.0 as an int and may hand back an
/// integer as a double, so either is accepted — but only if whole.
int? _int(Object? v) {
  if (v is int) return v;
  if (v is double && v == v.truncateToDouble()) return v.toInt();
  return null;
}

/// A server timestamp resolves to milliseconds since the epoch.
DateTime? _epochMs(Object? v) {
  final ms = _int(v);
  return ms == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
