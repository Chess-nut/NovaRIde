import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/errors/firebase_failure_mapper.dart';
import '../domain/entities/helmet_telemetry.dart';
import '../domain/repositories/helmet_telemetry_repository.dart';
import 'rtdb_helmet_nodes.dart';

/// The project's Realtime Database.
///
/// Passed explicitly because firebase_options.dart carries no
/// `databaseURL`, and without one the default instance resolves to
/// `novaride-7a68c-default-rtdb.firebaseio.com` — the us-central1 host.
/// This database is in asia-southeast1, which has a different host.
const helmetDatabaseUrl =
    'https://novaride-7a68c-default-rtdb.asia-southeast1.firebasedatabase.app';

/// How many log entries to read back for a last known position. The
/// firmware logs a position at most every 5 minutes, so ten is the last
/// ~50 minutes of tracking — enough to find a real fix behind a run of
/// pre-lock zeros, small enough not to download the whole history.
const _logWindow = 10;

/// [HelmetTelemetryRepository] against Realtime Database.
///
/// The helmet writes its readings and its position to several nodes at
/// different rates (the table is in rtdb_helmet_nodes.dart). This listens
/// to all of them and emits one merged [HelmetTelemetry] whenever any of
/// them changes:
///
/// * `deviceStatus/{id}` — the 30-second heartbeat: sensors, `lastSeen`.
/// * `devices/{id}` — its `safety` (every 10 s), `tracking` (position
///   every 5 min) and `latest` (position and speed on an alert) children.
/// * `trackingLogs/{id}` and `gpsLogs/{id}`, the last [_logWindow] entries
///   each — for a last known position when the nodes above hold none.
///
/// Before this read only `deviceStatus`, which has no position or speed,
/// so Home's Location tile and Current speed could never show anything.
///
/// Emits nothing until both `deviceStatus` and `devices/{id}` have answered
/// at least once, so the screen does not flash "no helmet" while the
/// second listener is still connecting. The logs fill in when they arrive.
class RtdbHelmetTelemetryRepository implements HelmetTelemetryRepository {
  RtdbHelmetTelemetryRepository({FirebaseDatabase? database})
    : _database =
          database ??
          FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: helmetDatabaseUrl,
          );

  final FirebaseDatabase _database;

  @override
  Stream<HelmetTelemetry?> watch(String deviceId) {
    final sources = <String, Query>{
      'status': _database.ref('deviceStatus/$deviceId'),
      'device': _database.ref('devices/$deviceId'),
      'trackingLogs':
          _database.ref('trackingLogs/$deviceId').limitToLast(_logWindow),
      'gpsLogs': _database.ref('gpsLogs/$deviceId').limitToLast(_logWindow),
    };

    final values = <String, Object?>{};
    final answered = <String>{};
    final subscriptions = <StreamSubscription<DatabaseEvent>>[];
    late final StreamController<HelmetTelemetry?> controller;

    void emit() {
      if (!answered.contains('status') || !answered.contains('device')) return;
      if (controller.isClosed) return;
      controller.add(
        mergeHelmetNodes(
          status: values['status'],
          device: values['device'],
          trackingLogs: values['trackingLogs'],
          gpsLogs: values['gpsLogs'],
        ),
      );
    }

    controller = StreamController<HelmetTelemetry?>(
      onListen: () {
        sources.forEach((key, query) {
          subscriptions.add(
            query.onValue.listen(
              (event) {
                values[key] = event.snapshot.value;
                answered.add(key);
                emit();
              },
              // The interface's error contract: a Failure with a sentence
              // on it, never a raw FirebaseException reaching a widget. A
              // failed log listener is reported too: better a visible
              // error and a retry than a location that silently never
              // comes.
              onError: (Object error, StackTrace stack) {
                if (!controller.isClosed) {
                  controller.addError(failureFrom(error, stack), stack);
                }
              },
            ),
          );
        });
      },
      // Every listener goes when the screen stops watching: four open
      // sockets per helmet otherwise, for as long as the app runs.
      onCancel: () async {
        await Future.wait([for (final s in subscriptions) s.cancel()]);
        subscriptions.clear();
        await controller.close();
      },
    );

    return controller.stream;
  }
}
