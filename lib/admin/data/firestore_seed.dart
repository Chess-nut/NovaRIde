import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:novaride/admin/mock/mock_data.dart';

/// Writes the simulation's seed fleet into Cloud Firestore, once, so the
/// dashboard has something to show before the first helmet exists.
///
/// Gated behind `--dart-define=SEED_FIRESTORE=true` and refuses to run
/// against a database that already has riders — it is a bootstrap for an
/// empty project, never a reset. Nothing outside `riders/`, `devices/` and
/// `alerts/` is touched; whatever a teammate has in other collections stays.
///
/// Field names follow `docs/FIRESTORE_SCHEMA.md`: camelCase on the
/// dashboard-owned collections, the firmware's snake_case on `devices/`.
Future<void> seedFirestore({FirebaseFirestore? firestore}) async {
  final db = firestore ?? FirebaseFirestore.instance;

  final existing = await db.collection('riders').limit(1).get();
  if (existing.docs.isNotEmpty) {
    throw StateError(
      'riders/ is not empty (found ${existing.docs.first.id}) — refusing to '
      'seed. Clear the collection in the console first if you really mean it.',
    );
  }

  final batch = db.batch();

  for (final rider in MockData.riders) {
    batch.set(db.collection('riders').doc(rider.id), {
      'fullName': rider.fullName,
      'helmetId': rider.helmetId,
      'phone': rider.phone,
      'status': rider.status.name,
      'isActive': rider.isActive,
      'registeredAt': Timestamp.fromDate(rider.registeredAt),
    });
  }

  for (final rider in MockData.riders) {
    final t = MockData.telemetryFor(rider.id);
    if (t == null) continue;
    batch.set(db.collection('devices').doc(rider.helmetId), {
      'assigned_rider_id': rider.id,
      'state': 'seeded',
      'firmware_version': 'seed',
      'paired_at': Timestamp.fromDate(rider.registeredAt),
      // Firmware-shaped readings, matching devices/helmet01.
      'alcohol_level': t.alcoholLevel,
      'ax': 0,
      'ay': 0,
      'az': 0,
      'vector_magnitude': 0,
      'severity': '',
      'latitude': t.lat,
      'longitude': t.lng,
      // Dashboard-required readings the firmware contract still has to add.
      'speed_kmh': t.speedKmh,
      'battery_pct': t.batteryPct,
      'gps_fix': t.gpsFix,
      'last_update': Timestamp.fromDate(t.lastUpdate),
    });
  }

  for (final alert in MockData.alerts) {
    final rider = MockData.riders.firstWhere((r) => r.id == alert.riderId);
    batch.set(db.collection('alerts').doc(alert.id), {
      'riderId': alert.riderId,
      'riderName': alert.riderName,
      'deviceId': rider.helmetId,
      'type': alert.type.name,
      'lat': alert.lat,
      'lng': alert.lng,
      'address': alert.address,
      'timestamp': Timestamp.fromDate(alert.timestamp),
      'status': alert.status.name,
    });
  }

  await batch.commit();
  debugPrint(
    'seedFirestore: wrote ${MockData.riders.length} riders, '
    '${MockData.telemetry.length} devices, ${MockData.alerts.length} alerts.',
  );
}
