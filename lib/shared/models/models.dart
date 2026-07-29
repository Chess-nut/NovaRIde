// Domain models shared by the rider app and the admin dashboard.
//
// Plain data classes for now — Phase 2 swaps the mock source for Firebase
// without changing these shapes.

enum RiderStatus { riding, idle, offline, emergency }

enum AlertType { crash, alcoholWarning, lowBattery, sos }

enum AlertStatus { open, acknowledged, dispatched, resolved }

class Rider {
  final String id;
  final String fullName;
  final String helmetId;
  final String phone;
  final RiderStatus status;

  const Rider({
    required this.id,
    required this.fullName,
    required this.helmetId,
    required this.phone,
    required this.status,
  });
}

class HelmetTelemetry {
  final String riderId;
  final double speedKmh;

  /// MQ-3 breath alcohol reading, 0.00–1.00 mg/L. Above 0.05 is a warning.
  final double alcoholLevel;
  final int batteryPct;
  final bool gpsFix;
  final double lat;
  final double lng;
  final DateTime lastUpdate;

  const HelmetTelemetry({
    required this.riderId,
    required this.speedKmh,
    required this.alcoholLevel,
    required this.batteryPct,
    required this.gpsFix,
    required this.lat,
    required this.lng,
    required this.lastUpdate,
  });
}

class AlertEvent {
  final String id;
  final String riderId;
  final String riderName;
  final AlertType type;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final AlertStatus status;

  const AlertEvent({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.type,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.status,
  });
}

/// Threshold above which a breath alcohol reading is flagged in amber.
const double kAlcoholWarningLevel = 0.05;

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
        AlertStatus.open => 'Open',
        AlertStatus.acknowledged => 'Acknowledged',
        AlertStatus.dispatched => 'Dispatched',
        AlertStatus.resolved => 'Resolved',
      };

  bool get isOpen => this == AlertStatus.open || this == AlertStatus.acknowledged;
}
