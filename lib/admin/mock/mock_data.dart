import 'package:novaride/shared/models/models.dart';

/// Static mock fleet for the Phase 1 dashboard shell.
/// Phase 2 replaces this file with a Firebase-backed repository; the widgets
/// consume the model types, not this class, so nothing else has to change.
class MockData {
  const MockData._();

  /// Timestamps are built relative to app start so "3m ago" stays sensible.
  static final DateTime _now = DateTime.now();

  static final List<Rider> riders = [
    Rider(
      id: 'R-001',
      fullName: 'Renato Villanueva',
      helmetId: 'NR-H1-001',
      phone: '+63 917 402 8813',
      status: RiderStatus.riding,
      registeredAt: _now.subtract(const Duration(days: 412)),
    ),
    Rider(
      id: 'R-002',
      fullName: 'Maricel Bautista',
      helmetId: 'NR-H1-002',
      phone: '+63 918 336 7420',
      status: RiderStatus.riding,
      registeredAt: _now.subtract(const Duration(days: 388)),
    ),
    Rider(
      id: 'R-003',
      fullName: 'Joselito Ramos',
      helmetId: 'NR-H1-003',
      phone: '+63 906 771 2094',
      status: RiderStatus.emergency,
      registeredAt: _now.subtract(const Duration(days: 341)),
    ),
    Rider(
      id: 'R-004',
      fullName: 'Divina Salazar',
      helmetId: 'NR-H1-004',
      phone: '+63 995 218 6647',
      status: RiderStatus.riding,
      registeredAt: _now.subtract(const Duration(days: 297)),
    ),
    Rider(
      id: 'R-005',
      fullName: 'Arnel Dela Cruz',
      helmetId: 'NR-H1-005',
      phone: '+63 927 553 1180',
      status: RiderStatus.idle,
      registeredAt: _now.subtract(const Duration(days: 265)),
    ),
    Rider(
      id: 'R-006',
      fullName: 'Rowena Manalo',
      helmetId: 'NR-H1-006',
      phone: '+63 939 807 4426',
      status: RiderStatus.riding,
      registeredAt: _now.subtract(const Duration(days: 233)),
    ),
    Rider(
      id: 'R-007',
      fullName: 'Edgardo Mercado',
      helmetId: 'NR-H1-007',
      phone: '+63 916 649 9037',
      status: RiderStatus.offline,
      registeredAt: _now.subtract(const Duration(days: 190)),
    ),
    Rider(
      id: 'R-008',
      fullName: 'Lorna Gatchalian',
      helmetId: 'NR-H1-008',
      phone: '+63 908 274 5561',
      status: RiderStatus.riding,
      registeredAt: _now.subtract(const Duration(days: 154)),
    ),
    Rider(
      id: 'R-009',
      fullName: 'Antonio Sarmiento',
      helmetId: 'NR-H1-009',
      phone: '+63 947 118 3392',
      status: RiderStatus.idle,
      registeredAt: _now.subtract(const Duration(days: 121)),
    ),
    Rider(
      id: 'R-010',
      fullName: 'Melinda Corpuz',
      helmetId: 'NR-H1-010',
      phone: '+63 922 960 7715',
      status: RiderStatus.offline,
      registeredAt: _now.subtract(const Duration(days: 78)),
    ),
  ];

  static final List<HelmetTelemetry> telemetry = [
    HelmetTelemetry(
      riderId: 'R-001',
      speedKmh: 42.5,
      alcoholLevel: 0.00,
      batteryPct: 87,
      gpsFix: true,
      lat: 14.6760,
      lng: 121.0437,
      lastUpdate: _now.subtract(const Duration(seconds: 4)),
    ),
    HelmetTelemetry(
      riderId: 'R-002',
      speedKmh: 28.3,
      alcoholLevel: 0.02,
      batteryPct: 64,
      gpsFix: true,
      lat: 14.6091,
      lng: 121.0223,
      lastUpdate: _now.subtract(const Duration(seconds: 7)),
    ),
    HelmetTelemetry(
      riderId: 'R-003',
      speedKmh: 0.0,
      alcoholLevel: 0.01,
      batteryPct: 58,
      gpsFix: true,
      lat: 14.5896,
      lng: 121.0614,
      lastUpdate: _now.subtract(const Duration(seconds: 2)),
    ),
    HelmetTelemetry(
      riderId: 'R-004',
      speedKmh: 51.8,
      alcoholLevel: 0.00,
      batteryPct: 92,
      gpsFix: true,
      lat: 14.6507,
      lng: 121.0489,
      lastUpdate: _now.subtract(const Duration(seconds: 5)),
    ),
    HelmetTelemetry(
      riderId: 'R-005',
      speedKmh: 0.0,
      alcoholLevel: 0.08,
      batteryPct: 41,
      gpsFix: true,
      lat: 14.5547,
      lng: 121.0244,
      lastUpdate: _now.subtract(const Duration(seconds: 11)),
    ),
    HelmetTelemetry(
      riderId: 'R-006',
      speedKmh: 36.1,
      alcoholLevel: 0.00,
      batteryPct: 73,
      gpsFix: true,
      lat: 14.6349,
      lng: 121.0783,
      lastUpdate: _now.subtract(const Duration(seconds: 3)),
    ),
    HelmetTelemetry(
      riderId: 'R-007',
      speedKmh: 0.0,
      alcoholLevel: 0.00,
      batteryPct: 12,
      gpsFix: false,
      lat: 14.6538,
      lng: 120.9842,
      lastUpdate: _now.subtract(const Duration(minutes: 14)),
    ),
    HelmetTelemetry(
      riderId: 'R-008',
      speedKmh: 47.9,
      alcoholLevel: 0.00,
      batteryPct: 80,
      gpsFix: true,
      lat: 14.5995,
      lng: 120.9842,
      lastUpdate: _now.subtract(const Duration(seconds: 6)),
    ),
    HelmetTelemetry(
      riderId: 'R-009',
      speedKmh: 0.0,
      alcoholLevel: 0.06,
      batteryPct: 55,
      gpsFix: true,
      lat: 14.5647,
      lng: 121.0287,
      lastUpdate: _now.subtract(const Duration(seconds: 19)),
    ),
    HelmetTelemetry(
      riderId: 'R-010',
      speedKmh: 0.0,
      alcoholLevel: 0.00,
      batteryPct: 8,
      gpsFix: false,
      lat: 14.5764,
      lng: 121.0851,
      lastUpdate: _now.subtract(const Duration(minutes: 23)),
    ),
  ];

  static final List<AlertEvent> alerts = [
    AlertEvent(
      id: 'A-101',
      riderId: 'R-003',
      riderName: 'Joselito Ramos',
      type: AlertType.crash,
      lat: 14.5896,
      lng: 121.0614,
      address: 'E. Rodriguez Sr. Ave',
      timestamp: _now.subtract(const Duration(minutes: 2)),
      status: AlertStatus.open,
    ),
    AlertEvent(
      id: 'A-100',
      riderId: 'R-005',
      riderName: 'Arnel Dela Cruz',
      type: AlertType.alcoholWarning,
      lat: 14.5547,
      lng: 121.0244,
      address: 'EDSA, Makati',
      timestamp: _now.subtract(const Duration(minutes: 17)),
      status: AlertStatus.acknowledged,
    ),
    AlertEvent(
      id: 'A-099',
      riderId: 'R-010',
      riderName: 'Melinda Corpuz',
      type: AlertType.lowBattery,
      lat: 14.5764,
      lng: 121.0851,
      address: 'Katipunan Ave, QC',
      timestamp: _now.subtract(const Duration(minutes: 44)),
      status: AlertStatus.open,
    ),
    AlertEvent(
      id: 'A-098',
      riderId: 'R-008',
      riderName: 'Lorna Gatchalian',
      type: AlertType.sos,
      lat: 14.5995,
      lng: 120.9842,
      address: 'España Blvd, Sampaloc',
      timestamp: _now.subtract(const Duration(hours: 2, minutes: 6)),
      status: AlertStatus.dispatched,
    ),
    AlertEvent(
      id: 'A-097',
      riderId: 'R-007',
      riderName: 'Edgardo Mercado',
      type: AlertType.lowBattery,
      lat: 14.6538,
      lng: 120.9842,
      address: 'Mindanao Ave, Novaliches',
      timestamp: _now.subtract(const Duration(hours: 5, minutes: 31)),
      status: AlertStatus.resolved,
    ),
  ];

  /// Alerts per weekday for the dashboard bar chart, Mon–Sun.
  static const List<int> alertsThisWeek = [4, 7, 3, 9, 6, 11, 5];

  static const List<String> weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static HelmetTelemetry? telemetryFor(String riderId) {
    for (final t in telemetry) {
      if (t.riderId == riderId) return t;
    }
    return null;
  }
}
