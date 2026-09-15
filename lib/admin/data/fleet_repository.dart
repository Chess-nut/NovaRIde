import 'package:novaride/shared/models/models.dart';

/// Where the console's fleet data is coming from. Shown as a chip in the top
/// bar so a demo can prove at a glance whether the board is real or simulated.
enum FleetSource { simulation, firestore }

extension FleetSourceLabel on FleetSource {
  String get label => switch (this) {
        FleetSource.simulation => 'SIMULATION',
        FleetSource.firestore => 'FIRESTORE',
      };
}

/// Health of the link between the console and its data source.
///
/// [disconnected] means the source is serving whatever it last had — the
/// board is still readable, but nothing new is arriving and writes queue.
enum FleetConnectionState { connecting, connected, disconnected }

/// One connection update. [message] carries the reason for a disconnect so
/// the operator sees "permission denied" rather than a bare red dot.
class FleetConnection {
  final FleetConnectionState state;
  final String? message;

  const FleetConnection(this.state, [this.message]);

  static const connecting = FleetConnection(FleetConnectionState.connecting);
  static const connected = FleetConnection(FleetConnectionState.connected);

  bool get isConnected => state == FleetConnectionState.connected;
}

/// Persistence contract for the fleet.
///
/// The repository knows nothing about workflow rules — legal alert
/// transitions, roster uniqueness, when a rider comes off emergency — all of
/// that lives in `FleetController`, which validates against its local copy
/// and only then asks the repository to persist. The repository's job is to
/// carry that write to the backing store and to echo the resulting state back
/// through the `watch*` streams, which are the single source of truth the
/// controller reads from.
///
/// Two implementations: `MockFleetRepository`, an in-process simulation with
/// timers, and `FirestoreFleetRepository`, backed by Cloud Firestore
/// snapshots. `FleetHost` picks one at startup; nothing below it cares which.
abstract class FleetRepository {
  FleetSource get source;

  /// Current roster, re-emitted in full on every change. Implementations
  /// must emit the current value to each new listener.
  Stream<List<Rider>> watchRiders();

  /// Latest reading per helmet, re-emitted in full on every change.
  Stream<List<HelmetTelemetry>> watchTelemetry();

  /// Alerts newest-first, capped by the implementation so a long session
  /// never grows the board unbounded.
  Stream<List<AlertEvent>> watchAlerts();

  Stream<FleetConnection> watchConnection();

  /// Registers a rider. The implementation decides what, if any, helmet
  /// record to create alongside — the simulation places a dot on the map
  /// immediately; a real store waits for the helmet to report in.
  Future<void> addRider(Rider rider);

  /// Replaces a rider's editable fields.
  Future<void> updateRider(Rider rider);

  /// Narrow write for the status alone, so an automatic status change never
  /// carries a stale copy of the rider's other fields over a concurrent edit.
  Future<void> setRiderStatus(String riderId, RiderStatus status);

  /// Moves an alert to [action.toStatus] and appends [action] to its audit
  /// trail. The two happen together — an alert must never claim a status its
  /// history does not account for.
  Future<void> transitionAlert(String alertId, AlertAction action);

  /// Cancels timers and subscriptions. The repository is unusable afterwards.
  void dispose();
}
