/// Reads the helmet's live telemetry.
///
/// Today that is Realtime Database `deviceStatus/{id}`; after the firmware
/// moves to Firestore it will be `devices/{id}` behind this same interface.
///
/// Read-only: the firmware owns this data. This app never writes it.
///
/// **Contract:** on failure, throw a `Failure` from
/// `core/errors/failure.dart` — never a `FirebaseException`. Callers may
/// assume the `message` on what they catch is fit to show.
library;

import '../entities/helmet_telemetry.dart';

abstract interface class HelmetTelemetryRepository {
  /// The helmet's latest telemetry, updating as the device writes.
  ///
  /// Emits null when there is nothing there — a helmet that has never
  /// reported, or a device id that does not exist.
  Stream<HelmetTelemetry?> watch(String deviceId);
}
