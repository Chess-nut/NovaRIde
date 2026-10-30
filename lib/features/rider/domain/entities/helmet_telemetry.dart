/// The `deviceStatus/{id}` node in Realtime Database, as the helmet
/// firmware writes it today.
///
/// Field names are the firmware's camelCase, not the snake_case of the
/// Firestore `devices/{id}` schema — the Firestore migration comes later
/// and will get its own mapping.
///
/// Every field is nullable, and null means "the helmet did not send it".
/// The firmware replaces the whole node on each write, and some of these
/// fields (lat, lng, speedKmph and the rest of the fix) are written to
/// other paths by some builds and may never appear here. A default would
/// turn that absence into a reading: a missing alcohol index shown as 0
/// is "not measured" shown as "sober". So there are none.
library;

class HelmetTelemetry {
  const HelmetTelemetry({
    this.deviceId,
    this.online,
    this.lastSeen,
    this.ip,
    this.cellularDataReady,
    this.accelerometerReady,
    this.accelMagnitudeG,
    this.accelXG,
    this.accelYG,
    this.accelZG,
    this.sw420Active,
    this.tiltDegrees,
    this.orientation,
    this.safetyEvent,
    this.mq3Raw,
    this.mq3Voltage,
    this.alcoholRelativeIndex,
    this.alcoholAlert,
    this.gpsNmeaChars,
    this.gpsValidSentences,
    this.lat,
    this.lng,
    this.speedKmph,
    this.altitudeM,
    this.satellites,
    this.gpsAgeMs,
    this.mapsUrl,
  });

  final String? deviceId;

  /// Always written as true — nothing on the device or in the database
  /// ever sets it false. Freshness of [lastSeen] is what says whether
  /// the helmet is actually still there.
  final bool? online;

  /// Server time of the helmet's last write (`{".sv":"timestamp"}`).
  final DateTime? lastSeen;
  final String? ip;
  final bool? cellularDataReady;

  final bool? accelerometerReady;

  /// Overall acceleration in g. About 1 at rest.
  final double? accelMagnitudeG;
  final double? accelXG;
  final double? accelYG;
  final double? accelZG;
  final bool? sw420Active;
  final double? tiltDegrees;
  final String? orientation;
  final String? safetyEvent;

  final int? mq3Raw;
  final double? mq3Voltage;

  /// The MQ-3's raw ADC count, uncalibrated. A relative index — not a
  /// percentage, not a breath or blood concentration.
  final double? alcoholRelativeIndex;

  /// The firmware's own verdict: [alcoholRelativeIndex] at or above the
  /// threshold configured on the device.
  final bool? alcoholAlert;

  final int? gpsNmeaChars;
  final int? gpsValidSentences;
  final double? lat;
  final double? lng;
  final double? speedKmph;
  final double? altitudeM;
  final int? satellites;
  final int? gpsAgeMs;
  final String? mapsUrl;

  /// [accelMagnitudeG], unless the helmet says its accelerometer is not
  /// ready. This node's firmware writes the magnitude unconditionally, so
  /// with the sensor down it sends 0.000 — a number nothing measured.
  double? get impactG => accelerometerReady == false ? null : accelMagnitudeG;

  /// Whether there is a usable GPS fix. Null when the helmet sent no
  /// position at all, which is not the same as having no fix.
  ///
  /// A position older than 30 s is not usable: that is the firmware's
  /// own `GPS_FIX_TIMEOUT_MS`.
  bool? get hasUsableFix {
    if (lat == null || lng == null) return null;
    final age = gpsAgeMs;
    return age == null || age <= 30000;
  }

  /// Whether the helmet wrote within [window] of [now].
  ///
  /// A timestamp slightly in the future (the phone's clock behind the
  /// server's) counts as fresh rather than stale.
  bool isFresh(DateTime now, Duration window) {
    final at = lastSeen;
    return at != null && now.difference(at) <= window;
  }

  /// Takes the node's value as Realtime Database hands it over: a map
  /// with string keys, typed `Map<Object?, Object?>` on Android.
  factory HelmetTelemetry.fromMap(Map<Object?, Object?> map) {
    return HelmetTelemetry(
      deviceId: _string(map['deviceId']),
      online: _bool(map['online']),
      lastSeen: _epochMs(map['lastSeen']),
      ip: _string(map['ip']),
      cellularDataReady: _bool(map['cellularDataReady']),
      accelerometerReady: _bool(map['accelerometerReady']),
      accelMagnitudeG: _double(map['accelMagnitudeG']),
      accelXG: _double(map['accelXG']),
      accelYG: _double(map['accelYG']),
      accelZG: _double(map['accelZG']),
      sw420Active: _bool(map['sw420Active']),
      tiltDegrees: _double(map['tiltDegrees']),
      orientation: _string(map['orientation']),
      safetyEvent: _string(map['safetyEvent']),
      mq3Raw: _int(map['mq3Raw']),
      mq3Voltage: _double(map['mq3Voltage']),
      alcoholRelativeIndex: _double(map['alcoholRelativeIndex']),
      alcoholAlert: _bool(map['alcoholAlert']),
      gpsNmeaChars: _int(map['gpsNmeaChars']),
      gpsValidSentences: _int(map['gpsValidSentences']),
      lat: _double(map['lat']),
      lng: _double(map['lng']),
      speedKmph: _double(map['speedKmph']),
      altitudeM: _double(map['altitudeM']),
      satellites: _int(map['satellites']),
      gpsAgeMs: _int(map['gpsAgeMs']),
      mapsUrl: _string(map['mapsUrl']),
    );
  }

  // A value of the wrong type is treated as absent, never coerced.
  static double? _double(Object? value) => value is num ? value.toDouble() : null;
  static bool? _bool(Object? value) => value is bool ? value : null;
  static String? _string(Object? value) => value is String ? value : null;

  /// Realtime Database hands back 512.0 as an int and may hand back an
  /// integer as a double, so either is accepted — but only if whole.
  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is double && value == value.truncateToDouble()) {
      return value.toInt();
    }
    return null;
  }

  /// A server timestamp resolves to milliseconds since the epoch.
  static DateTime? _epochMs(Object? value) {
    final ms = _int(value);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
}
