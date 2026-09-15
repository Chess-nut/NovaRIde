/// Coverage-area geography shared by the data layer, the controller and the
/// map widgets. Lives beside the repositories because the simulation places
/// riders by district, and the Firestore seed reuses the same centres.
library;

/// Geographic window the stylized basemap paints. Fixed rather than derived
/// from the riders so the live jitter never re-frames the map under the dots.
const double kFleetLatMin = 14.53;
const double kFleetLatMax = 14.75;
const double kFleetLngMin = 120.95;
const double kFleetLngMax = 121.12;

/// Coverage area. One district drives three things at once: a bar in the
/// "alerts by area" chart, a label on the map, and the street shown in the feed.
class FleetDistrict {
  final String name;

  /// Trimmed for the 9px bar-chart axis, which has ~40px per slot.
  final String shortLabel;

  /// Uppercase form scattered across the mock basemap.
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
