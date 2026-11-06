/// Coverage-area geography shared by the data layer, the controller and the
/// map widgets. Lives beside the repositories because the simulation places
/// riders by district, and the Firestore seed reuses the same centres.
library;

import 'dart:math' as math;

/// Where the map opens, and where "Recentre" goes with nothing to show:
/// central Metro Manila.
const double kMetroManilaLat = 14.6091;
const double kMetroManilaLng = 121.0223;
const double kMetroManilaZoom = 12;

/// How close to a district centre a point must be to count as that
/// district. Beyond it a point is "Outside coverage" — it is not given the
/// nearest district's name, which is how an alert with no fix (read as
/// 0,0) once showed up as "España Blvd, Sampaloc".
const double kDistrictRadiusKm = 3;

/// The area-chart bucket for alerts outside every district, or with no
/// position of their own.
const String kOutsideCoverage = 'Outside coverage';

/// Coverage area. One district drives a bar in the "alerts by area" chart
/// and the "Near …" label of an alert inside it. The street in [address] is
/// the simulation's seed text only; a live alert is never given it.
class FleetDistrict {
  final String name;

  /// Trimmed for the 9px bar-chart axis, which has ~40px per slot.
  final String shortLabel;

  /// Uppercase form, kept for the simulation's seed data.
  final String mapLabel;
  final String address;
  final double lat;
  final double lng;

  const FleetDistrict({
    required this.name,
    required this.shortLabel,
    required this.mapLabel,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

const List<FleetDistrict> kFleetDistricts = [
  FleetDistrict(
    name: 'Diliman',
    shortLabel: 'Diliman',
    mapLabel: 'QC-DILIMAN',
    address: 'Katipunan Ave, QC',
    lat: 14.6537,
    lng: 121.0687,
  ),
  FleetDistrict(
    name: 'Cubao',
    shortLabel: 'Cubao',
    mapLabel: 'CUBAO',
    address: 'Aurora Blvd, Cubao',
    lat: 14.6199,
    lng: 121.0530,
  ),
  FleetDistrict(
    name: 'Novaliches',
    shortLabel: 'Novali.',
    mapLabel: 'NOVALICHES',
    address: 'Mindanao Ave, Novaliches',
    lat: 14.7180,
    lng: 121.0333,
  ),
  FleetDistrict(
    name: 'Fairview',
    shortLabel: 'Fairvw',
    mapLabel: 'FAIRVIEW',
    address: 'Regalado Ave, Fairview',
    lat: 14.7297,
    lng: 121.0644,
  ),
  FleetDistrict(
    name: 'Commonwealth',
    shortLabel: 'Comm.',
    mapLabel: 'COMMONWEALTH',
    address: 'Commonwealth Ave, QC',
    lat: 14.6906,
    lng: 121.0801,
  ),
  FleetDistrict(
    name: 'Sampaloc',
    shortLabel: 'Sampa.',
    mapLabel: 'SAMPALOC',
    address: 'España Blvd, Sampaloc',
    lat: 14.6100,
    lng: 120.9950,
  ),
  FleetDistrict(
    name: 'Sta. Mesa',
    shortLabel: 'StaMesa',
    mapLabel: 'STA. MESA',
    address: 'E. Rodriguez Sr. Ave',
    lat: 14.5980,
    lng: 121.0150,
  ),
  FleetDistrict(
    name: 'Makati',
    shortLabel: 'Makati',
    mapLabel: 'MAKATI',
    address: 'EDSA, Makati',
    lat: 14.5547,
    lng: 121.0244,
  ),
];

/// District whose centre is closest to a fix. Squared planar distance — the
/// coverage area is small enough that great-circle maths would not change
/// the winner.
FleetDistrict nearestFleetDistrict(double lat, double lng) {
  var best = kFleetDistricts.first;
  var bestDistance = double.infinity;
  for (final d in kFleetDistricts) {
    final dLat = d.lat - lat;
    final dLng = d.lng - lng;
    final distance = dLat * dLat + dLng * dLng;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = d;
    }
  }
  return best;
}

/// Great-circle distance in kilometres (haversine). Accurate to well under
/// a percent at city scale, which is all the district rule needs.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// The district a point is in: the nearest centre, but only within
/// [radiusKm]. Null outside every district — the caller says "Outside
/// coverage", never the nearest name.
FleetDistrict? districtWithin(
  double lat,
  double lng, {
  double radiusKm = kDistrictRadiusKm,
}) {
  final nearest = nearestFleetDistrict(lat, lng);
  return distanceKm(lat, lng, nearest.lat, nearest.lng) <= radiusKm
      ? nearest
      : null;
}

/// A position a GPS module can actually report as a fix: in range, and not
/// the exact 0 a module reports before it has locked (the live database has
/// `lat: 0, lng: 0.366667` in it, which is not a place).
bool isRealPosition(double? lat, double? lng) =>
    lat != null &&
    lng != null &&
    lat != 0 &&
    lng != 0 &&
    lat.abs() <= 90 &&
    lng.abs() <= 180;
