// Domain models shared by the rider app and the admin dashboard.
//
// Plain data classes for now — Phase 2 swaps the mock source for Firebase
// without changing these shapes.

enum RiderStatus { riding, idle, offline, emergency }

enum AlertType { crash, alcoholWarning, lowBattery, sos }

/// `pending` is a crash inside its false-positive countdown, which its
/// rider may still cancel in the app; `cancelled` is one they did. Both are
/// docs/FIRMWARE_CONTRACT.md §3.8.
enum AlertStatus {
  pending,
  open,
  acknowledged,
  dispatched,
  resolved,
  cancelled,
}

/// How long a rider has to cancel a pending crash, from its server
/// timestamp. The rules enforce the same 15 s (firestore.rules,
/// countdownOpen); after it the alert is open whatever the app does.
const Duration kCrashCountdown = Duration(seconds: 15);

/// Emergency service an operator can dispatch to an incident.
enum ResponderType { medical, police, fireRescue, barangay }

class Rider {
  final String id;
  final String fullName;
  final String helmetId;
  final String phone;
  final RiderStatus status;

  /// Deactivated riders are kept, never deleted — alert history references
  /// rider IDs, so removing the row would orphan past incidents.
  final bool isActive;

  final DateTime registeredAt;

  /// The rider's own app account (`riders/{id}.authUid`), once a Super Admin
  /// has linked it. Null until then. The link is what lets the rider read
  /// their own alerts, and so answer the false-positive countdown.
  final String? authUid;

  Rider({
    required this.id,
    required this.fullName,
    required this.helmetId,
    required this.phone,
    required this.status,
    this.isActive = true,
    DateTime? registeredAt,
    this.authUid,
  }) : registeredAt = registeredAt ?? DateTime.now();

  Rider copyWith({
    String? id,
    String? fullName,
    String? helmetId,
    String? phone,
    RiderStatus? status,
    bool? isActive,
    DateTime? registeredAt,
  }) => Rider(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    helmetId: helmetId ?? this.helmetId,
    phone: phone ?? this.phone,
    status: status ?? this.status,
    isActive: isActive ?? this.isActive,
    registeredAt: registeredAt ?? this.registeredAt,
    authUid: authUid,
  );
}

/// Which helmet node a position was read from. The firmware writes a fix to
/// several Realtime Database nodes at different rates (see
/// `lib/admin/data/rtdb_fleet_merge.dart`), and an operator judging how far
/// to trust a dot needs to know which one it came from: a 30 s heartbeat, a
/// 5-minute tracking upload, or the last emergency upload hours ago.
enum PositionSource {
  /// `deviceStatus/{id}` — the 30 s heartbeat (newer firmware only).
  deviceStatus,

  /// `devices/{id}/latest` — written only when the helmet raises an alert.
  latest,

  /// `devices/{id}/tracking` — the 5-minute periodic upload.
  tracking,

  /// `trackingLogs/{id}/{pushId}` — history of the periodic uploads.
  trackingLogs,

  /// `gpsLogs/{id}/{pushId}` — history of the alert uploads.
  gpsLogs,

  /// Firestore `devices/{id}` (the `USE_FIRESTORE 1` firmware).
  firestore,

  /// The in-process simulation.
  simulation,
}

extension PositionSourceLabel on PositionSource {
  /// The node path, as the operator would find it in the Firebase console.
  String get label => switch (this) {
    PositionSource.deviceStatus => 'deviceStatus',
    PositionSource.latest => 'devices/…/latest',
    PositionSource.tracking => 'devices/…/tracking',
    PositionSource.trackingLogs => 'trackingLogs',
    PositionSource.gpsLogs => 'gpsLogs',
    PositionSource.firestore => 'Firestore devices/',
    PositionSource.simulation => 'Simulation',
  };
}

/// One real GPS position from a helmet, with the server time it was taken.
///
/// Used for the breadcrumb trail and for placing an alert that arrived with
/// no position of its own at the helmet's last known fix. "Real" is the
/// merge's rule: never a pre-lock 0 / zero-satellite reading.
class HelmetFix {
  final double lat;
  final double lng;

  /// When the fix was taken: the node's server time minus `gpsAgeMs`.
  final DateTime at;
  final PositionSource source;
  final double? speedKmph;

  /// The firmware's `reason` on a `gpsLogs` entry (`suspected-crash`).
  final String? reason;

  const HelmetFix({
    required this.lat,
    required this.lng,
    required this.at,
    required this.source,
    this.speedKmph,
    this.reason,
  });
}

/// One helmet's latest reading.
///
/// Every reading is nullable, and null means "the helmet did not send it".
/// A default would turn that absence into a reading — a missing speed shown
/// as 0.0 km/h is "not measured" shown as "stopped" — so there are none. The
/// label getters in [TelemetryReadout] turn every null into a dash.
class HelmetTelemetry {
  /// The rider this helmet is paired to. Null for a helmet that reports but
  /// is on nobody's roster entry: a real state the operator should see.
  final String? riderId;

  /// The helmet's serial / device id (`devices/{id}`, `deviceStatus/{id}`).
  final String? deviceId;

  /// Speed reported with the position, and only while that position is
  /// current — an old speed shown as "now" is worse than none.
  final double? speedKmh;

  /// The helmet's own verdict: MQ-3 vapour above that helmet's measured
  /// clean-air baseline (`alcohol_detected`). Null when the helmet sends no
  /// verdict — no baseline yet, sensor warming up, older firmware — which
  /// means "not measured" and must never be shown as sober.
  ///
  /// There is deliberately no number and no legal-limit comparison: RA 10586
  /// is zero tolerance for motorcycle riders, and a sensor inside a helmet
  /// measures the vapour in the helmet, not breath.
  final bool? alcoholDetected;

  /// The MQ-3's raw ADC count (`alcoholRelativeIndex`, 0–4095), uncalibrated.
  /// A relative index — not mg/L, not BAC — so it is shown as a raw number
  /// and never compared against any limit.
  final double? alcoholRawIndex;

  /// Overall acceleration in g (`accelMagnitudeG`), about 1 at rest. Null
  /// when the helmet says its accelerometer is not ready.
  ///
  /// Not a crash criterion since the Oct 30 consultation; shown under
  /// Diagnostics only.
  final double? accelMagnitudeG;

  /// Not sent by the Realtime Database firmware at all.
  final int? batteryPct;

  /// A usable fix that is still current (see the repository for "current").
  /// The one non-nullable reading: "no current fix" is what an absent
  /// position means.
  final bool gpsFix;
  final double? lat;
  final double? lng;

  /// Server time of the newest reading this value was built from.
  final DateTime? lastUpdate;

  // ------------------------------------------------- status (deviceStatus)

  /// Always written as true by the firmware — nothing ever sets it false.
  /// [lastSeen] freshness is what says whether the helmet is still there.
  final bool? online;

  /// Server time of the helmet's newest write to any node. Defaults to
  /// [lastUpdate] when not given; the two are the same reading for every
  /// source today.
  final DateTime? lastSeen;

  /// Wi-Fi address, or the literal `cellular` on the AIR780E link.
  final String? ip;
  final bool? cellularDataReady;
  final int? gpsNmeaChars;
  final int? gpsValidSentences;

  // ----------------------------------------------------------- safety

  /// SW-420 vibration switch. Reading only — the firmware uses its silence
  /// as one leg of the stationary-crash rule.
  final bool? sw420Active;

  /// When [sw420Active] last changed, as far as the console has seen —
  /// worked out by the repository from consecutive writes and the logs.
  /// Null when no change has been seen.
  final DateTime? sw420ChangedAt;
  final double? tiltDegrees;

  /// `Upright`, `Tilt`, `Side/abnormal` — the firmware's own words.
  final String? orientation;

  /// The firmware's safety state machine, verbatim: `Monitoring`,
  /// `Tilt/side posture: monitoring`, `Rider check alert: …`,
  /// `Crash alert: …`, `Alcohol threshold exceeded`.
  final String? safetyEvent;

  // ---------------------------------------------------------- alcohol

  final int? mq3Raw;
  final double? mq3Voltage;

  /// The raw-count threshold configured on the helmet (`alcoholThreshold`,
  /// `devices/{id}/safety` only). [alcoholDetected] is the helmet's own
  /// "raw index ≥ this" verdict. A raw count, not a concentration.
  final double? alcoholThreshold;

  // ----------------------------------------------------- accelerometer

  final bool? accelerometerReady;
  final double? accelXG;
  final double? accelYG;
  final double? accelZG;

  // -------------------------------------------------------------- GPS

  final int? satellites;
  final double? altitudeM;

  /// How old the fix already was when the helmet wrote it.
  final int? gpsAgeMs;

  /// When the position in [lat]/[lng] was taken, by the server's clock.
  final DateTime? fixAt;

  /// Google Maps link the firmware builds for the fix (alert uploads only).
  final String? mapsUrl;

  /// Which node [lat]/[lng] came from. Null without a position.
  final PositionSource? positionSource;

  const HelmetTelemetry({
    required this.riderId,
    this.deviceId,
    required this.speedKmh,
    this.alcoholDetected,
    this.alcoholRawIndex,
    this.accelMagnitudeG,
    required this.batteryPct,
    required this.gpsFix,
    required this.lat,
    required this.lng,
    required this.lastUpdate,
    this.online,
    DateTime? lastSeen,
    this.ip,
    this.cellularDataReady,
    this.gpsNmeaChars,
    this.gpsValidSentences,
    this.sw420Active,
    this.sw420ChangedAt,
    this.tiltDegrees,
    this.orientation,
    this.safetyEvent,
    this.mq3Raw,
    this.mq3Voltage,
    this.alcoholThreshold,
    this.accelerometerReady,
    this.accelXG,
    this.accelYG,
    this.accelZG,
    this.satellites,
    this.altitudeM,
    this.gpsAgeMs,
    this.fixAt,
    this.mapsUrl,
    this.positionSource,
  }) : lastSeen = lastSeen ?? lastUpdate;

  /// Copies with the given readings replaced. A copy can only replace a
  /// reading, never clear one to null — nothing in the console needs to,
  /// and a `null` meaning "keep" is what every other copyWith here does.
  HelmetTelemetry copyWith({
    String? riderId,
    String? deviceId,
    double? speedKmh,
    bool? alcoholDetected,
    double? alcoholRawIndex,
    double? accelMagnitudeG,
    int? batteryPct,
    bool? gpsFix,
    double? lat,
    double? lng,
    DateTime? lastUpdate,
    bool? online,
    DateTime? lastSeen,
    String? ip,
    bool? cellularDataReady,
    int? gpsNmeaChars,
    int? gpsValidSentences,
    bool? sw420Active,
    DateTime? sw420ChangedAt,
    double? tiltDegrees,
    String? orientation,
    String? safetyEvent,
    int? mq3Raw,
    double? mq3Voltage,
    double? alcoholThreshold,
    bool? accelerometerReady,
    double? accelXG,
    double? accelYG,
    double? accelZG,
    int? satellites,
    double? altitudeM,
    int? gpsAgeMs,
    DateTime? fixAt,
    String? mapsUrl,
    PositionSource? positionSource,
  }) => HelmetTelemetry(
    riderId: riderId ?? this.riderId,
    deviceId: deviceId ?? this.deviceId,
    speedKmh: speedKmh ?? this.speedKmh,
    alcoholDetected: alcoholDetected ?? this.alcoholDetected,
    alcoholRawIndex: alcoholRawIndex ?? this.alcoholRawIndex,
    accelMagnitudeG: accelMagnitudeG ?? this.accelMagnitudeG,
    batteryPct: batteryPct ?? this.batteryPct,
    gpsFix: gpsFix ?? this.gpsFix,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    lastUpdate: lastUpdate ?? this.lastUpdate,
    online: online ?? this.online,
    // A new lastUpdate moves lastSeen with it unless told otherwise.
    lastSeen: lastSeen ?? lastUpdate ?? this.lastSeen,
    ip: ip ?? this.ip,
    cellularDataReady: cellularDataReady ?? this.cellularDataReady,
    gpsNmeaChars: gpsNmeaChars ?? this.gpsNmeaChars,
    gpsValidSentences: gpsValidSentences ?? this.gpsValidSentences,
    sw420Active: sw420Active ?? this.sw420Active,
    sw420ChangedAt: sw420ChangedAt ?? this.sw420ChangedAt,
    tiltDegrees: tiltDegrees ?? this.tiltDegrees,
    orientation: orientation ?? this.orientation,
    safetyEvent: safetyEvent ?? this.safetyEvent,
    mq3Raw: mq3Raw ?? this.mq3Raw,
    mq3Voltage: mq3Voltage ?? this.mq3Voltage,
    alcoholThreshold: alcoholThreshold ?? this.alcoholThreshold,
    accelerometerReady: accelerometerReady ?? this.accelerometerReady,
    accelXG: accelXG ?? this.accelXG,
    accelYG: accelYG ?? this.accelYG,
    accelZG: accelZG ?? this.accelZG,
    satellites: satellites ?? this.satellites,
    altitudeM: altitudeM ?? this.altitudeM,
    gpsAgeMs: gpsAgeMs ?? this.gpsAgeMs,
    fixAt: fixAt ?? this.fixAt,
    mapsUrl: mapsUrl ?? this.mapsUrl,
    positionSource: positionSource ?? this.positionSource,
  );

  /// The newest reading time this value carries.
  DateTime? get heardAt => lastSeen ?? lastUpdate;

  /// The helmet's safety state machine is in a crash state.
  bool get reportsCrash =>
      (safetyEvent ?? '').toLowerCase().startsWith('crash alert');
}

/// What the helmet itself reported in Realtime Database that no Firestore
/// alert covers yet — a crash or rider-check state, an alcohol verdict going
/// true, or a new `gpsLogs` emergency upload.
///
/// Shown on the board as "Unconfirmed — from helmet" until an operator opens
/// it as a real alert. [id] is deterministic, `{deviceId}_{serverTimeMs}`,
/// so two consoles opening the same event create one alert, not two.
enum HelmetEventKind { crash, riderCheck, alcohol, emergencyUpload }

extension HelmetEventKindLabel on HelmetEventKind {
  String get label => switch (this) {
    HelmetEventKind.crash => 'Helmet crash alert',
    HelmetEventKind.riderCheck => 'Helmet rider check',
    HelmetEventKind.alcohol => 'Helmet alcohol alert',
    HelmetEventKind.emergencyUpload => 'Helmet emergency upload',
  };

  /// The alert type it would become if opened.
  AlertType get alertType => switch (this) {
    HelmetEventKind.crash => AlertType.crash,
    HelmetEventKind.riderCheck => AlertType.crash,
    HelmetEventKind.alcohol => AlertType.alcoholWarning,
    HelmetEventKind.emergencyUpload => AlertType.crash,
  };

  /// `severity` for the alert document (firestore.rules allows exactly
  /// `low` / `moderate` / `high`). A rider check is a suspicion, not a
  /// crash, so it opens as moderate.
  String get severity => switch (this) {
    HelmetEventKind.crash => 'high',
    HelmetEventKind.riderCheck => 'moderate',
    HelmetEventKind.alcohol => 'moderate',
    HelmetEventKind.emergencyUpload => 'high',
  };
}

class HelmetEvent {
  /// `{deviceId}_{serverTimeMs}` — also the alert id it would open as.
  final String id;
  final String deviceId;
  final HelmetEventKind kind;

  /// Server time of the write that carried the event.
  final DateTime at;

  /// The firmware's own words: the `safetyEvent` text or the `gpsLogs`
  /// `reason`.
  final String detail;

  /// Paired rider, if the roster has one. An event from an unassigned helmet
  /// is still shown but cannot be opened: an alert needs a `riderId`.
  final String? riderId;
  final String? riderName;

  /// The position the event's own node carried, if it was a real fix.
  final double? lat;
  final double? lng;

  const HelmetEvent({
    required this.id,
    required this.deviceId,
    required this.kind,
    required this.at,
    required this.detail,
    this.riderId,
    this.riderName,
    this.lat,
    this.lng,
  });

  HelmetEvent withRider(String? riderId, String? riderName) => HelmetEvent(
    id: id,
    deviceId: deviceId,
    kind: kind,
    at: at,
    detail: detail,
    riderId: riderId,
    riderName: riderName,
    lat: lat,
    lng: lng,
  );

  bool get hasPosition => lat != null && lng != null;
}

/// One audit entry in an alert's response history.
///
/// The thesis question is response time, so every status change records who
/// made it and when — [AlertEvent.history] is what the timeline and the
/// average-response metrics are computed from.
class AlertAction {
  final AlertStatus toStatus;
  final String actorName;
  final String? note;

  /// Only set on a dispatch, where the operator picks a service.
  final ResponderType? responder;
  final DateTime at;

  const AlertAction({
    required this.toStatus,
    required this.actorName,
    this.note,
    this.responder,
    required this.at,
  });
}

class AlertEvent {
  final String id;
  final String riderId;
  final String riderName;
  final AlertType type;

  /// The position the alert itself carried. Null when it carried none — a
  /// crash with no GPS fix must still reach the board (FIRMWARE_CONTRACT.md
  /// §3.1), and it must never be plotted at 0,0 or given a made-up street.
  final double? lat;
  final double? lng;

  /// What the feed shows for "where": the alert's own `address` if it has
  /// one, else a description of [lat]/[lng], else of [lastKnownFix], else
  /// "Location unavailable". Never an invented street.
  final String address;
  final DateTime timestamp;
  final AlertStatus status;

  /// The helmet that raised it (`deviceId` on the document), when known.
  final String? deviceId;

  /// For an alert with no position of its own: the helmet's newest real fix
  /// taken at or before [timestamp]. Labelled "Last known position", never
  /// shown as the alert's location.
  final HelmetFix? lastKnownFix;

  /// Append-only audit trail, oldest first. Empty for an untouched alert.
  final List<AlertAction> history;

  const AlertEvent({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.type,
    required this.lat,
    required this.lng,
    required this.address,
    required this.timestamp,
    required this.status,
    this.deviceId,
    this.lastKnownFix,
    this.history = const [],
  });

  bool get hasPosition => lat != null && lng != null;

  AlertEvent copyWith({
    String? id,
    String? riderId,
    String? riderName,
    AlertType? type,
    double? lat,
    double? lng,
    String? address,
    DateTime? timestamp,
    AlertStatus? status,
    String? deviceId,
    HelmetFix? lastKnownFix,
    List<AlertAction>? history,
  }) => AlertEvent(
    id: id ?? this.id,
    riderId: riderId ?? this.riderId,
    riderName: riderName ?? this.riderName,
    type: type ?? this.type,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    address: address ?? this.address,
    timestamp: timestamp ?? this.timestamp,
    status: status ?? this.status,
    deviceId: deviceId ?? this.deviceId,
    lastKnownFix: lastKnownFix ?? this.lastKnownFix,
    history: history ?? this.history,
  );

  /// When the alert first reached [status], or null if it never did.
  DateTime? reachedAt(AlertStatus status) {
    for (final action in history) {
      if (action.toStatus == status) return action.at;
    }
    return null;
  }
}

/// The only three things the console may say about alcohol. "Not measured"
/// is its own state, so a helmet that sends nothing never reads as sober.
extension AlcoholReadout on HelmetTelemetry {
  String get alcoholLabel => switch (alcoholDetected) {
    true => 'Detected',
    false => 'Not detected',
    null => 'Not measured',
  };
}

/// Text for the numeric readings. A reading the helmet did not send is a
/// dash, never 0.
extension TelemetryReadout on HelmetTelemetry {
  static const missing = '—';

  String get speedLabel {
    final v = speedKmh;
    return v == null ? missing : '${v.toStringAsFixed(1)} km/h';
  }

  String get batteryLabel {
    final v = batteryPct;
    return v == null ? missing : '$v%';
  }

  /// Battery the helmet reported as under 20%. Unknown is not low.
  bool get batteryLow => (batteryPct ?? 100) < 20;

  String get alcoholRawLabel {
    final v = alcoholRawIndex;
    return v == null ? missing : '${v.toStringAsFixed(0)} raw (0–4095)';
  }

  String get accelLabel {
    final v = accelMagnitudeG;
    return v == null ? missing : '${v.toStringAsFixed(2)} g';
  }

  /// "0.18 / −0.99 / 0.35 g".
  String get accelAxesLabel {
    final (x, y, z) = (accelXG, accelYG, accelZG);
    if (x == null && y == null && z == null) return missing;
    String f(double? v) => v == null ? missing : v.toStringAsFixed(2);
    return '${f(x)} / ${f(y)} / ${f(z)} g';
  }

  String get coordinatesLabel {
    final la = lat;
    final ln = lng;
    if (la == null || ln == null) return 'No position';
    return '${la.toStringAsFixed(5)}, ${ln.toStringAsFixed(5)}';
  }

  /// The helmet's verdict against its own threshold, in those words. Not
  /// "detected" / "sober": the comparison is a raw count against a raw count.
  String get alcoholVerdictLabel => switch (alcoholDetected) {
    true => 'Above threshold',
    false => 'Below threshold',
    null => 'Not measured',
  };

  /// "Raw 812 / threshold 900 — Below threshold". Never BAC or mg/L.
  String get alcoholThresholdLabel {
    final raw = alcoholRawIndex;
    final threshold = alcoholThreshold;
    if (raw == null && threshold == null && alcoholDetected == null) {
      return missing;
    }
    final rawText = raw == null ? missing : raw.toStringAsFixed(0);
    final thresholdText = threshold == null
        ? missing
        : threshold.toStringAsFixed(0);
    return 'Raw $rawText / threshold $thresholdText — $alcoholVerdictLabel';
  }

  String get mq3VoltageLabel {
    final v = mq3Voltage;
    return v == null ? missing : '${v.toStringAsFixed(3)} V';
  }

  String get alcoholThresholdValueLabel {
    final v = alcoholThreshold;
    return v == null ? missing : '${v.toStringAsFixed(0)} raw';
  }

  /// SW-420: "Active" (vibration sensed) or "Quiet".
  String get vibrationLabel => switch (sw420Active) {
    true => 'Active',
    false => 'Quiet',
    null => missing,
  };

  /// "40.4° · Side/abnormal".
  String get tiltLabel {
    final t = tiltDegrees;
    final o = orientation;
    if (t == null) return o ?? missing;
    final degrees = '${t.toStringAsFixed(1)}°';
    return o == null ? degrees : '$degrees · $o';
  }

  String get safetyEventLabel => safetyEvent ?? missing;

  String get satellitesLabel {
    final v = satellites;
    return v == null ? missing : '$v';
  }

  String get altitudeLabel {
    final v = altitudeM;
    return v == null ? missing : '${v.toStringAsFixed(1)} m';
  }

  String get onlineLabel => switch (online) {
    true => 'Reports online',
    false => 'Reports offline',
    null => missing,
  };

  String get ipLabel => ip ?? missing;

  String get cellularLabel => switch (cellularDataReady) {
    true => 'Ready',
    false => 'Not ready',
    null => missing,
  };

  String get positionSourceLabel => positionSource?.label ?? missing;

  String get nmeaLabel {
    final chars = gpsNmeaChars;
    final valid = gpsValidSentences;
    if (chars == null && valid == null) return missing;
    return '${chars ?? missing} chars · ${valid ?? missing} valid sentences';
  }
}

extension RiderStatusLabel on RiderStatus {
  String get label => switch (this) {
    RiderStatus.riding => 'Riding',
    RiderStatus.idle => 'Idle',
    RiderStatus.offline => 'Offline',
    RiderStatus.emergency => 'Emergency',
  };
}

extension AlertTypeLabel on AlertType {
  String get label => switch (this) {
    AlertType.crash => 'Crash Detected',
    AlertType.alcoholWarning => 'Alcohol Warning',
    AlertType.lowBattery => 'Low Battery',
    AlertType.sos => 'SOS Triggered',
  };

  /// Crash and SOS are the two life-critical events.
  bool get isCritical => this == AlertType.crash || this == AlertType.sos;
}

extension AlertStatusLabel on AlertStatus {
  String get label => switch (this) {
    AlertStatus.pending => 'Awaiting rider',
    AlertStatus.open => 'Open',
    AlertStatus.acknowledged => 'Acknowledged',
    AlertStatus.dispatched => 'Dispatched',
    AlertStatus.resolved => 'Resolved',
    AlertStatus.cancelled => 'Cancelled by rider',
  };

  /// Needs a dispatcher. A pending crash counts: it is on the board, and a
  /// dispatcher may act on it before the countdown ends.
  bool get isOpen =>
      this == AlertStatus.pending ||
      this == AlertStatus.open ||
      this == AlertStatus.acknowledged;

  /// Still consuming dispatch attention. Unlike [isOpen] this counts
  /// `dispatched` — responders are rolling but the incident is not closed.
  /// A cancelled alert is over: the rider said it was a false positive.
  bool get isActive =>
      this != AlertStatus.resolved && this != AlertStatus.cancelled;

  /// The alert lifecycle is strictly linear:
  ///
  ///     open → acknowledged → dispatched → resolved
  ///
  /// Skipping a step or moving backwards is rejected, so the audit trail can
  /// never claim a responder was sent to an alert nobody had acknowledged.
  AlertStatus? get nextStatus => switch (this) {
    AlertStatus.pending => AlertStatus.acknowledged,
    AlertStatus.open => AlertStatus.acknowledged,
    AlertStatus.acknowledged => AlertStatus.dispatched,
    AlertStatus.dispatched => AlertStatus.resolved,
    AlertStatus.resolved => null,
    AlertStatus.cancelled => null,
  };

  bool canTransitionTo(AlertStatus target) => nextStatus == target;
}

extension ResponderTypeLabel on ResponderType {
  String get label => switch (this) {
    ResponderType.medical => 'Medical / EMS',
    ResponderType.police => 'Police',
    ResponderType.fireRescue => 'Fire & Rescue',
    ResponderType.barangay => 'Barangay Response',
  };
}
