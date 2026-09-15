import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:novaride/admin/data/fleet_geography.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/shared/models/models.dart';

/// Cloud Firestore-backed fleet. Schema in `docs/FIRESTORE_SCHEMA.md`.
///
/// Four listeners feed three streams: `riders/`, `devices/`, `alerts/` and
/// the `history` collection group. Devices are joined to riders here — the
/// dashboard thinks in riders, the firmware thinks in helmets — and history
/// entries are stitched onto their alert so the pages see one [AlertEvent]
/// with its audit trail, exactly as the simulation hands it over.
///
/// Parsing is deliberately forgiving. A field that is missing or the wrong
/// type falls back to a sensible default; a document that cannot be read at
/// all is skipped with a `debugPrint`. One malformed write from a helmet must
/// never blank an operator's board mid-shift.
///
/// Writes use `update()` with explicit field paths (or `set` with merge) so
/// the console never erases a field it does not know about — the helmet
/// writes its own into the same documents.
class FirestoreFleetRepository implements FleetRepository {
  FirestoreFleetRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance {
    _start();
  }

  /// Newest alerts kept on the board. An uncapped listener bills every
  /// document on every change and slows down over a long session.
  static const alertLimit = 100;

  /// Audit entries fetched newest-first. At most three per alert, so this
  /// comfortably covers everything on the board.
  static const historyLimit = 500;

  /// If no snapshot arrives in this window the link is reported as down —
  /// the web SDK does not error while offline, it simply stays quiet.
  static const _firstSnapshotTimeout = Duration(seconds: 15);

  static const _minBackoff = Duration(seconds: 2);
  static const _maxBackoff = Duration(seconds: 30);

  final FirebaseFirestore _db;

  final _ridersCtrl = StreamController<List<Rider>>.broadcast();
  final _telemetryCtrl = StreamController<List<HelmetTelemetry>>.broadcast();
  final _alertsCtrl = StreamController<List<AlertEvent>>.broadcast();
  final _connectionCtrl = StreamController<FleetConnection>.broadcast();

  List<Rider> _riders = const [];
  List<HelmetTelemetry> _telemetry = const [];
  List<AlertEvent> _alerts = const [];
  FleetConnection _connection = FleetConnection.connecting;

  /// Raw inputs kept so either side of a join can be recomputed when the
  /// other changes.
  QuerySnapshot<Map<String, dynamic>>? _deviceDocs;
  List<AlertEvent> _bareAlerts = const [];
  Map<String, List<AlertAction>> _historyByAlert = const {};

  bool _ridersLoaded = false;
  bool _telemetryLoaded = false;
  bool _alertsLoaded = false;
  bool _disposed = false;

  final Map<String, StreamSubscription<dynamic>> _subs = {};
  final Map<String, Timer> _retries = {};
  final Map<String, Duration> _backoff = {};
  Timer? _firstSnapshotTimer;

  @override
  FleetSource get source => FleetSource.firestore;

  // --------------------------------------------------------------- streams

  @override
  Stream<List<Rider>> watchRiders() =>
      _replaying(() => _ridersLoaded ? _riders : null, _ridersCtrl.stream);

  @override
  Stream<List<HelmetTelemetry>> watchTelemetry() => _replaying(
      () => _telemetryLoaded ? _telemetry : null, _telemetryCtrl.stream);

  @override
  Stream<List<AlertEvent>> watchAlerts() =>
      _replaying(() => _alertsLoaded ? _alerts : null, _alertsCtrl.stream);

  @override
  Stream<FleetConnection> watchConnection() =>
      _replaying(() => _connection, _connectionCtrl.stream);

  /// New listeners get the latest value (once there is one), then updates.
  Stream<T> _replaying<T>(T? Function() current, Stream<T> updates) {
    return Stream<T>.multi((controller) {
      final value = current();
      if (value != null) controller.add(value);
      final sub = updates.listen(controller.add, onDone: controller.close);
      controller.onCancel = sub.cancel;
    }, isBroadcast: true);
  }

  // ------------------------------------------------------------- listeners

  void _start() {
    _firstSnapshotTimer = Timer(_firstSnapshotTimeout, () {
      if (_connection.state == FleetConnectionState.connecting) {
        _setConnection(const FleetConnection(
          FleetConnectionState.disconnected,
          'No response from Firestore — check the network and the rules.',
        ));
      }
    });
    _listenRiders();
    _listenDevices();
    _listenAlerts();
    _listenHistory();
  }

  void _listenRiders() {
    _subscribe(
      'riders',
      _db.collection('riders').snapshots(includeMetadataChanges: true),
      (QuerySnapshot<Map<String, dynamic>> snap) {
        _riders = [
          for (final doc in snap.docs)
            ?_parse(doc, _riderFrom),
        ];
        _ridersLoaded = true;
        _ridersCtrl.add(_riders);
        // Riders are the join key for devices and the name source for
        // alerts, so both views are refreshed off the same snapshot.
        _publishTelemetry();
        _publishAlerts();
        _reportMetadata(snap.metadata);
      },
    );
  }

  void _listenDevices() {
    _subscribe(
      'devices',
      _db.collection('devices').snapshots(includeMetadataChanges: true),
      (QuerySnapshot<Map<String, dynamic>> snap) {
        _deviceDocs = snap;
        _telemetryLoaded = true;
        _publishTelemetry();
        _reportMetadata(snap.metadata);
      },
    );
  }

  void _listenAlerts() {
    _subscribe(
      'alerts',
      _db
          .collection('alerts')
          .orderBy('timestamp', descending: true)
          .limit(alertLimit)
          .snapshots(includeMetadataChanges: true),
      (QuerySnapshot<Map<String, dynamic>> snap) {
        _bareAlerts = [
          for (final doc in snap.docs)
            ?_parse(doc, _alertFrom),
        ];
        _alertsLoaded = true;
        _publishAlerts();
        _reportMetadata(snap.metadata);
      },
    );
  }

  /// One collection-group listener rather than one per alert: the board
  /// holds up to [alertLimit] alerts, and a listener each would be wasteful.
  /// Needs the `history.at` collection-group index in firestore.indexes.json.
  void _listenHistory() {
    _subscribe(
      'history',
      _db
          .collectionGroup('history')
          .orderBy('at', descending: true)
          .limit(historyLimit)
          .snapshots(),
      (QuerySnapshot<Map<String, dynamic>> snap) {
        final grouped = <String, List<AlertAction>>{};
        for (final doc in snap.docs) {
          final alertId = doc.reference.parent.parent?.id;
          if (alertId == null) continue;
          final action = _parse(doc, _actionFrom);
          if (action == null) continue;
          grouped.putIfAbsent(alertId, () => []).add(action);
        }
        // Newest-first from the query; the model wants oldest-first.
        for (final list in grouped.values) {
          list.sort((a, b) => a.at.compareTo(b.at));
        }
        _historyByAlert = grouped;
        _publishAlerts();
      },
      affectsConnection: false,
    );
  }

  /// Wires one listener with restart-on-error. Each listener backs off on
  /// its own, so a missing index on `history` cannot take `riders` down.
  void _subscribe<T>(
    String name,
    Stream<T> stream,
    void Function(T snapshot) onData, {
    bool affectsConnection = true,
  }) {
    if (_disposed) return;
    _subs[name]?.cancel();
    _subs[name] = stream.listen(
      (snapshot) {
        _backoff.remove(name);
        onData(snapshot);
      },
      onError: (Object error) {
        final message = _describe(error);
        debugPrint('FirestoreFleetRepository[$name]: $message');
        if (affectsConnection) {
          _setConnection(
            FleetConnection(FleetConnectionState.disconnected, message),
          );
        }
        _scheduleRestart(name);
      },
    );
  }

  void _scheduleRestart(String name) {
    if (_disposed) return;
    final delay = _backoff[name] ?? _minBackoff;
    _backoff[name] = delay * 2 > _maxBackoff ? _maxBackoff : delay * 2;
    _retries[name]?.cancel();
    _retries[name] = Timer(delay, () {
      switch (name) {
        case 'riders':
          _listenRiders();
        case 'devices':
          _listenDevices();
        case 'alerts':
          _listenAlerts();
        case 'history':
          _listenHistory();
      }
    });
  }

  /// Snapshot metadata is the honest signal: a snapshot served from cache
  /// means the SDK could not reach the server, whether or not it has said so.
  void _reportMetadata(SnapshotMetadata metadata) {
    _firstSnapshotTimer?.cancel();
    if (metadata.isFromCache) {
      _setConnection(const FleetConnection(
        FleetConnectionState.disconnected,
        'Showing cached data — Firestore is unreachable.',
      ));
    } else {
      _setConnection(FleetConnection.connected);
    }
  }

  void _setConnection(FleetConnection connection) {
    if (_disposed) return;
    if (_connection.state == connection.state &&
        _connection.message == connection.message) {
      return;
    }
    _connection = connection;
    _connectionCtrl.add(connection);
  }

  static String _describe(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Firestore denied access — deploy rules that allow the console.',
        'failed-precondition' =>
          'Firestore needs an index — deploy firestore.indexes.json.',
        'unavailable' => 'Firestore is unreachable.',
        _ => 'Firestore error: ${error.code}',
      };
    }
    return 'Firestore error: $error';
  }

  // ----------------------------------------------------------------- joins

  void _publishTelemetry() {
    final docs = _deviceDocs;
    if (docs == null) return;
    _telemetry = [
      for (final doc in docs.docs)
        ?_parse(doc, _telemetryFrom),
    ];
    if (_telemetryLoaded) _telemetryCtrl.add(_telemetry);
  }

  void _publishAlerts() {
    if (!_alertsLoaded) return;
    _alerts = [
      for (final alert in _bareAlerts)
        alert.copyWith(
          riderName: alert.riderName.isEmpty
              ? (_riderById(alert.riderId)?.fullName ?? alert.riderId)
              : alert.riderName,
          history: _historyByAlert[alert.id] ?? const [],
        ),
    ];
    _alertsCtrl.add(_alerts);
  }

  Rider? _riderById(String id) {
    for (final r in _riders) {
      if (r.id == id) return r;
    }
    return null;
  }

  Rider? _riderByHelmet(String helmetId) {
    final wanted = helmetId.toUpperCase();
    for (final r in _riders) {
      if (r.helmetId.toUpperCase() == wanted) return r;
    }
    return null;
  }

  // --------------------------------------------------------------- parsing

  /// Runs one document parser, turning any failure into a skipped row.
  T? _parse<T>(
    DocumentSnapshot<Map<String, dynamic>> doc,
    T? Function(String id, Map<String, dynamic> data) parser,
  ) {
    try {
      final data = doc.data();
      if (data == null) return null;
      return parser(doc.id, data);
    } catch (error) {
      debugPrint(
        'FirestoreFleetRepository: skipped ${doc.reference.path}: $error',
      );
      return null;
    }
  }

  Rider? _riderFrom(String id, Map<String, dynamic> d) {
    final fullName = _str(d, ['fullName', 'full_name', 'name']);
    if (fullName == null) {
      debugPrint('FirestoreFleetRepository: riders/$id has no fullName');
      return null;
    }
    return Rider(
      id: id,
      fullName: fullName,
      helmetId: _str(d, ['helmetId', 'helmet_id', 'deviceId']) ?? '',
      phone: _str(d, ['phone', 'phoneNumber', 'phone_number']) ?? '',
      status: _enum(RiderStatus.values, _str(d, ['status'])) ??
          RiderStatus.idle,
      isActive: _bool(d, ['isActive', 'is_active']) ?? true,
      registeredAt:
          _date(d, ['registeredAt', 'registered_at', 'createdAt']) ??
              DateTime.now(),
    );
  }

  /// A device is only telemetry once it maps to a rider: by an explicit
  /// assignment on the document, else by the rider whose helmet serial is
  /// the document id. Unassigned helmets are not an error, just invisible.
  HelmetTelemetry? _telemetryFrom(String deviceId, Map<String, dynamic> d) {
    final assigned = _str(d, ['assigned_rider_id', 'assignedRiderId']);
    final rider = assigned != null
        ? (_riderById(assigned) ?? _riderByHelmet(deviceId))
        : _riderByHelmet(deviceId);
    if (rider == null) return null;

    final lat = _num(d, ['latitude', 'lat']) ?? 0;
    final lng = _num(d, ['longitude', 'lng', 'lon']) ?? 0;
    return HelmetTelemetry(
      riderId: rider.id,
      speedKmh: _num(d, ['speed_kmh', 'speedKmh', 'speed']) ?? 0,
      alcoholLevel: _num(d, ['alcohol_level', 'alcoholLevel']) ?? 0,
      batteryPct: (_num(d, ['battery_pct', 'batteryPct', 'battery']) ?? 0)
          .round()
          .clamp(0, 100),
      gpsFix: _bool(d, ['gps_fix', 'gpsFix']) ?? (lat != 0 || lng != 0),
      lat: lat,
      lng: lng,
      lastUpdate:
          _date(d, ['last_update', 'lastUpdate', 'last_seen', 'lastSeen']) ??
              DateTime.now(),
    );
  }

  AlertEvent? _alertFrom(String id, Map<String, dynamic> d) {
    final riderId = _str(d, ['riderId', 'rider_id']) ?? '';
    final point = _point(d);
    final type = _alertType(_str(d, ['type', 'alert_type', 'severity']));
    return AlertEvent(
      id: id,
      riderId: riderId,
      riderName: _str(d, ['riderName', 'rider_name']) ?? '',
      type: type,
      lat: point.$1,
      lng: point.$2,
      address: _str(d, ['address']) ??
          nearestFleetDistrict(point.$1, point.$2).address,
      timestamp:
          _date(d, ['timestamp', 'created_at', 'createdAt']) ?? DateTime.now(),
      status: _enum(AlertStatus.values, _str(d, ['status'])) ??
          AlertStatus.open,
    );
  }

  AlertAction? _actionFrom(String id, Map<String, dynamic> d) {
    final toStatus = _enum(AlertStatus.values, _str(d, ['toStatus']));
    if (toStatus == null) return null;
    return AlertAction(
      toStatus: toStatus,
      actorName: _str(d, ['actorName']) ?? 'Unknown operator',
      note: _str(d, ['note']),
      responder: _enum(ResponderType.values, _str(d, ['responder'])),
      // Null while a server timestamp is pending on the local echo.
      at: _date(d, ['at']) ?? DateTime.now(),
    );
  }

  /// Firmware naming is not settled, so common spellings all map. Anything
  /// unrecognised is shown as an SOS rather than dropped — a live alert with
  /// an odd label beats a hidden one.
  static AlertType _alertType(String? raw) {
    switch (raw?.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'crash':
      case 'fall':
      case 'impact':
      case 'collision':
        return AlertType.crash;
      case 'alcoholwarning':
      case 'alcohol':
      case 'drunk':
        return AlertType.alcoholWarning;
      case 'lowbattery':
      case 'battery':
        return AlertType.lowBattery;
      case 'sos':
      case 'panic':
      case 'emergency':
        return AlertType.sos;
      default:
        if (raw != null) {
          debugPrint('FirestoreFleetRepository: unknown alert type "$raw"');
        }
        return AlertType.sos;
    }
  }

  /// `lat`/`lng` fields, a `location` GeoPoint, or a `location` map.
  static (double, double) _point(Map<String, dynamic> d) {
    final lat = _num(d, ['lat', 'latitude']);
    final lng = _num(d, ['lng', 'longitude', 'lon']);
    if (lat != null && lng != null) return (lat, lng);

    final location = d['location'];
    if (location is GeoPoint) return (location.latitude, location.longitude);
    if (location is Map) {
      final map = location.cast<String, dynamic>();
      return (
        _num(map, ['lat', 'latitude']) ?? 0,
        _num(map, ['lng', 'longitude', 'lon']) ?? 0,
      );
    }
    return (0, 0);
  }

  static String? _str(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return null;
  }

  static double? _num(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static bool? _bool(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final lower = v.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
    }
    return null;
  }

  static DateTime? _date(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is num) {
        // Seconds from the firmware's RTC, or milliseconds from JS.
        final ms = v > 1e11 ? v.toInt() : (v * 1000).toInt();
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static T? _enum<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    final wanted = name.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    for (final v in values) {
      if (v.name.toLowerCase() == wanted) return v;
    }
    return null;
  }

  // ---------------------------------------------------------------- writes

  @override
  Future<void> addRider(Rider rider) {
    return _db.collection('riders').doc(rider.id).set({
      'fullName': rider.fullName,
      'helmetId': rider.helmetId,
      'phone': rider.phone,
      'status': rider.status.name,
      'isActive': rider.isActive,
      'registeredAt': Timestamp.fromDate(rider.registeredAt),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateRider(Rider rider) {
    return _db.collection('riders').doc(rider.id).update({
      'fullName': rider.fullName,
      'helmetId': rider.helmetId,
      'phone': rider.phone,
      'status': rider.status.name,
      'isActive': rider.isActive,
    });
  }

  @override
  Future<void> setRiderStatus(String riderId, RiderStatus status) {
    return _db.collection('riders').doc(riderId).update({
      'status': status.name,
    });
  }

  /// Status change and audit entry go in one batch so neither can land
  /// without the other. `at` is the server clock: response-time metrics are
  /// the study's evidence, and operator machines are not a trustworthy
  /// source for them. The `<status>At` stamp on the alert itself lets the
  /// Reports tab query response times without reading every history entry.
  @override
  Future<void> transitionAlert(String alertId, AlertAction action) {
    final alertRef = _db.collection('alerts').doc(alertId);
    final batch = _db.batch();
    batch.update(alertRef, {
      'status': action.toStatus.name,
      '${action.toStatus.name}At': FieldValue.serverTimestamp(),
    });
    batch.set(alertRef.collection('history').doc(), {
      'toStatus': action.toStatus.name,
      'actorName': action.actorName,
      'note': action.note,
      'responder': action.responder?.name,
      'at': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  @override
  void dispose() {
    _disposed = true;
    _firstSnapshotTimer?.cancel();
    for (final timer in _retries.values) {
      timer.cancel();
    }
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _ridersCtrl.close();
    _telemetryCtrl.close();
    _alertsCtrl.close();
    _connectionCtrl.close();
  }
}
