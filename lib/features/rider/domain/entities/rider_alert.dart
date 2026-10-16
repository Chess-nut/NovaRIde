/// The rider's own side of the console's roster and alerts.
///
/// A rider reaches these only once a Super Admin has linked their roster
/// entry to this account (`riders/{R-xxx}.authUid`); before that the rules
/// refuse both, and the app treats "not linked" as a state, not an error.
library;

/// `riders/{R-xxx}` as its own rider may read it.
class LinkedRider {
  const LinkedRider({
    required this.riderId,
    required this.fullName,
    required this.helmetId,
    required this.status,
  });

  /// The roster id, `R-001`. Alerts are filed under it.
  final String riderId;
  final String fullName;
  final String helmetId;

  /// `riding` | `idle` | `offline` | `emergency`, as the console has it.
  final String status;

  factory LinkedRider.fromMap(String riderId, Map<String, dynamic> map) {
    return LinkedRider(
      riderId: riderId,
      fullName: map['fullName'] as String? ?? '',
      helmetId: map['helmetId'] as String? ?? '',
      status: map['status'] as String? ?? 'idle',
    );
  }
}

enum RiderAlertStatus {
  /// A crash the helmet raised, inside its false-positive countdown.
  pending,
  open,
  acknowledged,
  dispatched,
  resolved,

  /// Called off by the rider during the countdown.
  cancelled,

  /// A status this build does not know. Shown, never dropped.
  unknown;

  static RiderAlertStatus parse(Object? raw) {
    for (final s in values) {
      if (s.name == raw) return s;
    }
    return unknown;
  }
}

/// `alerts/{id}`, one of this rider's.
class RiderAlert {
  const RiderAlert({
    required this.id,
    required this.riderId,
    required this.type,
    required this.severity,
    required this.status,
    this.timestamp,
  });

  final String id;
  final String riderId;

  /// `crash` | `sos` | `alcoholWarning` | `lowBattery`.
  final String type;

  /// `low` | `moderate` | `high`.
  final String severity;
  final RiderAlertStatus status;

  /// The server's time of arrival. Null only while a local write is
  /// pending, which a rider's read-only listener never has.
  final DateTime? timestamp;

  factory RiderAlert.fromMap(String id, Map<String, dynamic> map) {
    return RiderAlert(
      id: id,
      riderId: map['riderId'] as String? ?? '',
      type: map['type'] as String? ?? '',
      severity: map['severity'] as String? ?? '',
      status: RiderAlertStatus.parse(map['status']),
      timestamp: _dateFrom(map['timestamp']),
    );
  }

  /// Anything with a `toDate()` — a Firestore `Timestamp` — without this
  /// file importing one.
  static DateTime? _dateFrom(Object? value) {
    if (value is DateTime) return value;
    try {
      final converted = (value as dynamic)?.toDate();
      return converted is DateTime ? converted : null;
    } catch (_) {
      return null;
    }
  }
}
