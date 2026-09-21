import 'package:flutter/material.dart';

enum RiderStatus { safe, riding, warning, accidentDetected, sosActive, offline, resolved }
enum PermissionType { liveLocation, emergencyAlerts, tripStatus, helmetStatus, incidentHistory }

class ConnectedRider {
  final String id, name, relationship, avatarLetters, address, destination, heading;
  final RiderStatus status;
  final double speedKmh, latitude, longitude;
  final int tripDurationMinutes, batteryPct, lastUpdatedSeconds;
  final bool helmetConnected, gpsActive, internetConnected, impactNormal, alcoholSafe, gpsLocked, isCurrentlyRiding, activeEmergency;
  final DateTime lastUpdated;

  const ConnectedRider({
    required this.id, required this.name, required this.relationship, required this.avatarLetters,
    required this.status, required this.speedKmh, required this.tripDurationMinutes,
    required this.destination, required this.address, required this.batteryPct,
    required this.helmetConnected, required this.gpsActive, required this.internetConnected,
    required this.impactNormal, required this.alcoholSafe, required this.gpsLocked,
    required this.isCurrentlyRiding, required this.lastUpdatedSeconds, required this.latitude,
    required this.longitude, required this.heading, required this.lastUpdated, required this.activeEmergency,
  });

  ConnectedRider copyWith({RiderStatus? status, DateTime? lastUpdated, int? lastUpdatedSeconds, bool? activeEmergency}) => ConnectedRider(
    id: id, name: name, relationship: relationship, avatarLetters: avatarLetters,
    status: status ?? this.status, speedKmh: speedKmh, tripDurationMinutes: tripDurationMinutes,
    destination: destination, address: address, batteryPct: batteryPct,
    helmetConnected: helmetConnected, gpsActive: gpsActive, internetConnected: internetConnected,
    impactNormal: impactNormal, alcoholSafe: alcoholSafe, gpsLocked: gpsLocked,
    isCurrentlyRiding: isCurrentlyRiding, lastUpdatedSeconds: lastUpdatedSeconds ?? this.lastUpdatedSeconds,
    latitude: latitude, longitude: longitude, heading: heading,
    lastUpdated: lastUpdated ?? this.lastUpdated, activeEmergency: activeEmergency ?? this.activeEmergency,
  );
}

class Incident {
  final String id, title, location, status, severity, riderStatus, incidentType, gpsInfo, durationLabel;
  final DateTime timestamp;
  final bool sosTriggered, riderCancelledAlert;

  const Incident({required this.id, required this.title, required this.location, required this.timestamp, required this.status, required this.severity, required this.riderStatus, required this.incidentType, required this.gpsInfo, required this.sosTriggered, required this.riderCancelledAlert, required this.durationLabel});
}

class Permission {
  final PermissionType type;
  final String label;
  final bool enabled;
  const Permission({required this.type, required this.label, required this.enabled});
}

extension RiderStatusText on RiderStatus {
  String get label => switch (this) {
    RiderStatus.safe => 'SAFE', RiderStatus.riding => 'RIDING', RiderStatus.warning => 'WARNING',
    RiderStatus.accidentDetected => 'ACCIDENT DETECTED', RiderStatus.sosActive => 'SOS ACTIVE',
    RiderStatus.offline => 'OFFLINE', RiderStatus.resolved => 'RESOLVED',
  };
  Color get color => switch (this) {
    RiderStatus.safe => const Color(0xFF3DDC97), RiderStatus.riding => const Color(0xFF4CC9F0),
    RiderStatus.warning => const Color(0xFFFFB020), RiderStatus.accidentDetected => const Color(0xFFFF3B5C),
    RiderStatus.sosActive => const Color(0xFFEF476F), RiderStatus.offline => const Color(0xFF6C7280),
    RiderStatus.resolved => const Color(0xFF7DD3FC),
  };
}
