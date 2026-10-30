import 'package:flutter/foundation.dart';

@immutable
class RiderLocation {
  final String riderId;
  final double latitude;
  final double longitude;
  final double? speedKmh;
  final double? heading;
  final DateTime? timestamp;
  final String status;
  final String? address;

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
}
