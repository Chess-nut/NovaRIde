import 'package:flutter/material.dart';

enum FamilyRiderStatus {
  safe,
  riding,
  warning,
  accidentDetected,
  sosActive,
  offline,
  resolved,
}

enum FamilyConnectionStatus { pending, accepted, declined, revoked }

enum FamilyPermissionType {
  liveLocation,
  emergencyAlerts,
  tripStatus,
  helmetStatus,
  incidentHistory,
}

class FamilyConnectedRider {
  final String id;
  final String name;
  final String relationship;
  final String avatarLetters;
  final FamilyRiderStatus status;
  final double speedKmh;
  final int tripDurationMinutes;
  final String destination;
  final String address;
  final int batteryPct;
  final bool helmetConnected;
  final bool gpsActive;
  final bool internetConnected;
  final bool impactNormal;
  final bool alcoholSafe;
  final bool gpsLocked;
  final bool isCurrentlyRiding;
  final int lastUpdatedSeconds;
  final double latitude;
  final double longitude;
  final String heading;
  final DateTime lastUpdated;
  final bool activeEmergency;

  const FamilyConnectedRider({
    required this.id,
    required this.name,
    required this.relationship,
    required this.avatarLetters,
    required this.status,
    required this.speedKmh,
    required this.tripDurationMinutes,
    required this.destination,
    required this.address,
    required this.batteryPct,
    required this.helmetConnected,
    required this.gpsActive,
    required this.internetConnected,
    required this.impactNormal,
    required this.alcoholSafe,
    required this.gpsLocked,
    required this.isCurrentlyRiding,
    required this.lastUpdatedSeconds,
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.lastUpdated,
    required this.activeEmergency,
  });

  FamilyConnectedRider copyWith({
    FamilyRiderStatus? status,
    double? speedKmh,
    int? tripDurationMinutes,
    String? destination,
    String? address,
    int? batteryPct,
    bool? helmetConnected,
    bool? gpsActive,
    bool? internetConnected,
    bool? impactNormal,
    bool? alcoholSafe,
    bool? gpsLocked,
    bool? isCurrentlyRiding,
    int? lastUpdatedSeconds,
    double? latitude,
    double? longitude,
    String? heading,
    DateTime? lastUpdated,
    bool? activeEmergency,
  }) {
    return FamilyConnectedRider(
      id: id,
      name: name,
      relationship: relationship,
      avatarLetters: avatarLetters,
      status: status ?? this.status,
      speedKmh: speedKmh ?? this.speedKmh,
      tripDurationMinutes: tripDurationMinutes ?? this.tripDurationMinutes,
      destination: destination ?? this.destination,
      address: address ?? this.address,
      batteryPct: batteryPct ?? this.batteryPct,
      helmetConnected: helmetConnected ?? this.helmetConnected,
      gpsActive: gpsActive ?? this.gpsActive,
      internetConnected: internetConnected ?? this.internetConnected,
      impactNormal: impactNormal ?? this.impactNormal,
      alcoholSafe: alcoholSafe ?? this.alcoholSafe,
      gpsLocked: gpsLocked ?? this.gpsLocked,
      isCurrentlyRiding: isCurrentlyRiding ?? this.isCurrentlyRiding,
      lastUpdatedSeconds: lastUpdatedSeconds ?? this.lastUpdatedSeconds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      activeEmergency: activeEmergency ?? this.activeEmergency,
    );
  }
}

class FamilyIncident {
  final String id;
  final String title;
  final String location;
  final DateTime timestamp;
  final String status;
  final String severity;
  final String riderStatus;
  final String incidentType;
  final String gpsInfo;
  final bool sosTriggered;
  final bool riderCancelledAlert;
  final String durationLabel;

  const FamilyIncident({
    required this.id,
    required this.title,
    required this.location,
    required this.timestamp,
    required this.status,
    required this.severity,
    required this.riderStatus,
    required this.incidentType,
    required this.gpsInfo,
    required this.sosTriggered,
    required this.riderCancelledAlert,
    required this.durationLabel,
  });
}

class FamilyConnectionRequest {
  final String riderCode;
  final String riderName;
  final String relationship;
  final bool isAccepted;

  const FamilyConnectionRequest({
    required this.riderCode,
    required this.riderName,
    required this.relationship,
    required this.isAccepted,
  });
}

class FamilyPermission {
  final FamilyPermissionType type;
  final String label;
  final bool enabled;

  const FamilyPermission({
    required this.type,
    required this.label,
    required this.enabled,
  });
}

class FamilyUserProfile {
  final String name;
  final String relationship;
  final String phoneNumber;
  final String email;
  final String connectedRider;

  const FamilyUserProfile({
    required this.name,
    required this.relationship,
    required this.phoneNumber,
    required this.email,
    required this.connectedRider,
  });
}

extension FamilyStatusText on FamilyRiderStatus {
  String get label => switch (this) {
        FamilyRiderStatus.safe => 'SAFE',
        FamilyRiderStatus.riding => 'RIDING',
        FamilyRiderStatus.warning => 'WARNING',
        FamilyRiderStatus.accidentDetected => 'ACCIDENT DETECTED',
        FamilyRiderStatus.sosActive => 'SOS ACTIVE',
        FamilyRiderStatus.offline => 'OFFLINE',
        FamilyRiderStatus.resolved => 'RESOLVED',
      };

  Color get color => switch (this) {
        FamilyRiderStatus.safe => const Color(0xFF3DDC97),
        FamilyRiderStatus.riding => const Color(0xFF4CC9F0),
        FamilyRiderStatus.warning => const Color(0xFFFFB020),
        FamilyRiderStatus.accidentDetected => const Color(0xFFFF3B5C),
        FamilyRiderStatus.sosActive => const Color(0xFFEF476F),
        FamilyRiderStatus.offline => const Color(0xFF6C7280),
        FamilyRiderStatus.resolved => const Color(0xFF7DD3FC),
      };
}
