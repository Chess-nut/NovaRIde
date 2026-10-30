import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/errors/firebase_failure_mapper.dart';
import '../domain/entities/helmet_telemetry.dart';
import '../domain/repositories/helmet_telemetry_repository.dart';

/// The project's Realtime Database.
///
/// Passed explicitly because firebase_options.dart carries no
/// `databaseURL`, and without one the default instance resolves to
/// `novaride-7a68c-default-rtdb.firebaseio.com` — the us-central1 host.
/// This database is in asia-southeast1, which has a different host.
const helmetDatabaseUrl =
    'https://novaride-7a68c-default-rtdb.asia-southeast1.firebasedatabase.app';

/// [HelmetTelemetryRepository] against Realtime Database.
///
/// A live listener, so each write the helmet makes reaches the screen
/// without anything having to refresh.
class RtdbHelmetTelemetryRepository implements HelmetTelemetryRepository {
  RtdbHelmetTelemetryRepository({FirebaseDatabase? database})
      : _database = database ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: helmetDatabaseUrl,
            );

  final FirebaseDatabase _database;

  @override
  Stream<HelmetTelemetry?> watch(String deviceId) {
    return _database
        .ref('deviceStatus/$deviceId')
        .onValue
        .map((event) {
          // Anything but a map — no node, or a bare value where the node
          // should be — is "nothing there", not telemetry full of nulls.
          final value = event.snapshot.value;
          return value is Map<Object?, Object?>
              ? HelmetTelemetry.fromMap(value)
              : null;
        })
        // The interface's error contract: a Failure with a sentence on
        // it, never a raw FirebaseException reaching a widget.
        .handleError((Object error, StackTrace stack) =>
            throw failureFrom(error, stack));
  }
}
