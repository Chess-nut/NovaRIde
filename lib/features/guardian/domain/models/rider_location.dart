import 'package:flutter/foundation.dart';

@immutable
class RiderLocation {
  final String riderId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double? heading;
  final DateTime timestamp;
  final String status;
  final String address;

  const RiderLocation({
    required this.riderId,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.heading,
    required this.timestamp,
    required this.status,
    required this.address,
  });

  factory RiderLocation.fromMap(String riderId, Map<String, dynamic> data) {
    final timestampValue = data['timestamp'];
    final timestamp = timestampValue is DateTime
        ? timestampValue
        : DateTime.tryParse(timestampValue?.toString() ?? '') ?? DateTime.now();

    return RiderLocation(
      riderId: riderId,
      latitude: _number(data['latitude']),
      longitude: _number(data['longitude']),
      speedKmh: _number(data['speed'] ?? data['speedKmh']),
      heading: data['heading'] == null ? null : _number(data['heading']),
      timestamp: timestamp,
      status: data['status']?.toString() ?? 'OFFLINE',
      address: data['address']?.toString() ?? 'Location unavailable',
    );
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
