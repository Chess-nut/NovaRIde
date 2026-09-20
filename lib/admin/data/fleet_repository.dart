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

/// A write the store refused or could not complete, carrying a message
/// written for the operator at the keyboard.
///
/// Provider codes (`permission-denied`, `unavailable`) mean nothing on a
/// dispatch floor, so the repository translates before throwing and the
/// roster page shows [message] verbatim. `FleetController` adds one case of
/// its own — a write that produced no answer within its deadline.
class FleetWriteException implements Exception {
  final String message;

  const FleetWriteException(this.message);

  @override
  String toString() => 'FleetWriteException: $message';
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

  /// Registers a rider and pairs their helmet, returning the record as
  /// saved. The id may differ from `rider.id`: the controller suggests the
  /// next sequential one, and a store shared between operators claims the
  /// first free id at or after it, so two consoles adding at once get two
  /// riders, not one overwritten. The helmet must not already be paired to
  /// somebody else; the store checks that at write time, not from a list.
  ///
  /// Every write here either lands or throws a [FleetWriteException] — it
  /// never queues silently for a network that may not come back.
  Future<Rider> addRider(Rider rider);

  /// Replaces a rider's editable fields with explicit field paths, and moves
  /// the helmet pairing if the serial changed. Never a bare set: the helmet
  /// writes its own fields into the same documents.
  Future<void> updateRider(Rider rider);

  /// Narrow write for deactivation and reactivation: `isActive` and the
  /// matching status (offline / idle), nothing else, so it can never carry a
  /// stale name or phone over another operator's concurrent edit. The rider
  /// is kept — alert history references rider ids.
  Future<void> setRiderActive(String riderId, bool active);

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

/// Builds the repository a `FleetHost` hands to its controller.
typedef FleetRepositoryFactory = FleetRepository Function();
