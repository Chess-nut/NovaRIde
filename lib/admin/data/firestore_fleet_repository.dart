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
/// Roster writes run as transactions (see [addRider]) so that two operators
/// working at once cannot claim the same rider id or the same helmet, and
/// so that a console with no network fails fast instead of queueing a write
/// that the operator would see as saved. They use explicit field paths — the
/// helmet writes its own fields into the same documents, and the console
/// never erases one it does not know about.
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

  /// How many consecutive rider ids one add will try before giving up.
  /// Each try is one read inside the transaction; ten covers ten operators
  /// registering at the same instant, which is nine more than the fleet has.
  static const idClaimAttempts = 10;

  /// Registers the rider in one transaction:
  ///
  /// 1. Claims a rider id. The controller suggests the next sequential
  ///    `R-###` from its copy of the roster; the transaction reads that
  ///    document and, if another operator got there first, walks forward to
  ///    the first free one. Sequential ids are kept on purpose — they appear
  ///    on the map, in every alert tile and in the paper's figures, where a
  ///    twenty-character auto-id would be noise. A transaction makes them
  ///    safe: if two consoles race for `R-011`, Firestore retries the loser,
  ///    which then reads `R-011` as taken and claims `R-012`.
  /// 2. Reads `devices/{helmetId}`. If it is paired to a different rider the
  ///    add is refused with a message. The document is the uniqueness anchor
  ///    — one document per helmet, read under the transaction — so a clash
  ///    is caught at the store even when the other operator's rider has not
  ///    reached this console's listener yet.
  /// 3. Writes the rider and the pairing (`assigned_rider_id`, `paired_at`)
  ///    on the device document, creating it if the helmet has never reported.
  ///
  /// Transactions have no local echo and fail when the client is offline,
  /// which is exactly what the roster wants: the controller shows the rider
  /// at once and withdraws them if this throws.
  @override
  Future<Rider> addRider(Rider rider) => _guard(() async {
        final outcome = await _db.runTransaction<_Outcome<Rider>>((tx) async {
          final riders = _db.collection('riders');

          // Reads first — a Firestore transaction refuses a read after a
          // write. The id walk and the pairing check are both reads.
          var id = rider.id;
          var claimed = false;
          for (var attempt = 0; attempt < idClaimAttempts; attempt++) {
            final taken = (await tx.get(riders.doc(id))).exists;
            if (!taken) {
              claimed = true;
              break;
            }
            final next = _nextRiderId(id);
            if (next == null) break;
            id = next;
          }
          if (!claimed) {
            return _refuse(
              'Could not find a free rider id near ${rider.id} — the roster '
              'is changing quickly. Try again.',
            );
          }

          final pairing = await _readPairing(tx, rider.helmetId);
          if (pairing.holder != null && pairing.holder != id) {
            return _refuse(
              'Helmet ${rider.helmetId} was assigned to ${pairing.holder} by '
              'another operator. Choose a different helmet.',
            );
          }

          tx.set(riders.doc(id), {
            'fullName': rider.fullName,
            'helmetId': rider.helmetId,
            'phone': rider.phone,
            'status': rider.status.name,
            'isActive': rider.isActive,
            'registeredAt': Timestamp.fromDate(rider.registeredAt),
          });
          _writePairing(tx, rider.helmetId, id);
          return _saved(rider.copyWith(id: id));
        });
        return _settle(outcome);
      });

  /// Edits the rider's own fields by path and moves the helmet pairing if the
  /// serial changed: the new device gains `assigned_rider_id`, the old one
  /// loses it, all in the same transaction as the rider update. A helmet
  /// already paired to somebody else is refused at the store.
  @override
  Future<void> updateRider(Rider rider) => _guard(() async {
        final outcome = await _db.runTransaction<_Outcome<bool>>((tx) async {
          final ref = _db.collection('riders').doc(rider.id);
          final current = await tx.get(ref);
          if (!current.exists) {
            return _refuse(
              '${rider.id} is no longer on the roster — another operator may '
              'have removed it. Refresh and try again.',
            );
          }
          final previousHelmet =
              _str(current.data() ?? const {}, ['helmetId', 'helmet_id']) ??
                  '';

          final pairing = await _readPairing(tx, rider.helmetId);
          if (pairing.holder != null && pairing.holder != rider.id) {
            return _refuse(
              'Helmet ${rider.helmetId} is assigned to ${pairing.holder}. '
              'Choose a different helmet.',
            );
          }
          final releasing = previousHelmet.isNotEmpty &&
                  previousHelmet.toUpperCase() != rider.helmetId.toUpperCase()
              ? await _readPairing(tx, previousHelmet)
              : null;

          tx.update(ref, {
            'fullName': rider.fullName,
            'helmetId': rider.helmetId,
            'phone': rider.phone,
            'status': rider.status.name,
            'isActive': rider.isActive,
          });
          if (pairing.holder != rider.id) {
            _writePairing(tx, rider.helmetId, rider.id);
          }
          // Only unpair a device this rider actually held; a device the
          // helmet service has since re-pointed elsewhere is left alone.
          if (releasing != null && releasing.holder == rider.id) {
            tx.update(releasing.ref, {
              'assigned_rider_id': FieldValue.delete(),
              'paired_at': FieldValue.delete(),
            });
          }
          return _saved(true);
        });
        _settle(outcome);
      });

  @override
  Future<void> setRiderActive(String riderId, bool active) => _guard(() async {
        final outcome = await _db.runTransaction<_Outcome<bool>>((tx) async {
          final ref = _db.collection('riders').doc(riderId);
          if (!(await tx.get(ref)).exists) {
            return _refuse(
              '$riderId is no longer on the roster — another operator may '
              'have removed it. Refresh and try again.',
            );
          }
          tx.update(ref, {
            'isActive': active,
            'status': (active ? RiderStatus.idle : RiderStatus.offline).name,
          });
          return _saved(true);
        });
        _settle(outcome);
      });

  /// A transaction handler's verdict. Refusals travel back as a value, not
  /// an exception: every refusal above is decided before the first write, so
  /// returning normally commits nothing — and the handler runs inside the
  /// web SDK's promise machinery, across which a thrown Dart object is not
  /// guaranteed to come back as itself. [_settle] turns a refusal into the
  /// [FleetWriteException] the controller expects.
  static _Outcome<T> _refuse<T>(String message) =>
      (value: null, refusal: message);

  static _Outcome<T> _saved<T>(T value) => (value: value, refusal: null);

  static T _settle<T>(_Outcome<T> outcome) {
    final refusal = outcome.refusal;
    if (refusal != null) throw FleetWriteException(refusal);
    return outcome.value as T;
  }

  /// The device document and who it is paired to, read under [tx].
  Future<({DocumentReference<Map<String, dynamic>> ref, String? holder})>
      _readPairing(Transaction tx, String helmetId) async {
    final ref = _db.collection('devices').doc(helmetId);
    final snapshot = await tx.get(ref);
    final holder = snapshot.exists
        ? _str(snapshot.data() ?? const {},
            ['assigned_rider_id', 'assignedRiderId'])
        : null;
    return (ref: ref, holder: holder);
  }

  /// The console's side of `devices/`: the pairing fields and nothing else.
  /// Merge, because the document may already hold the helmet's telemetry —
  /// or may not exist yet, when a rider is registered before their helmet
  /// first reports in.
  void _writePairing(Transaction tx, String helmetId, String riderId) {
    tx.set(
      _db.collection('devices').doc(helmetId),
      {
        'assigned_rider_id': riderId,
        'paired_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// `R-011` → `R-012`; null for an id outside the sequential scheme, which
  /// the id walk treats as "give up" rather than invent a scheme.
  static String? _nextRiderId(String id) {
    final match = RegExp(r'^R-(\d+)$').firstMatch(id.toUpperCase());
    if (match == null) return null;
    final number = int.parse(match.group(1)!) + 1;
    return 'R-${number.toString().padLeft(3, '0')}';
  }

  /// Runs one write, turning whatever it throws into a [FleetWriteException]
  /// the operator can read. Messages the write raised itself pass through.
  Future<T> _guard<T>(Future<T> Function() write) async {
    try {
      return await write();
    } on FleetWriteException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint('FirestoreFleetRepository: write refused — '
          '${error.plugin}/${error.code}: ${error.message}');
      throw FleetWriteException(messageForWriteCode(error.code));
    } catch (error, stack) {
      debugPrint('FirestoreFleetRepository: write threw $error\n$stack');
      throw const FleetWriteException(
        'The change was not saved. Try again, and tell a Super Admin if it '
        'keeps happening.',
      );
    }
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

/// What a roster transaction decided: the saved value, or why it declined.
typedef _Outcome<T> = ({T? value, String? refusal});

/// Turns a `cloud_firestore` error code from a roster write into a sentence
/// for the person at the keyboard. Never returns the code itself.
String messageForWriteCode(String code) {
  return switch (code) {
    'permission-denied' =>
      'Firestore refused the change. Only a Super Admin may edit the '
          'roster, and the security rules must be deployed.',
    'unavailable' || 'deadline-exceeded' || 'network-request-failed' =>
      'Cannot reach Firestore — the change was not saved. Check the '
          'connection and try again.',
    'aborted' =>
      'Another operator changed the roster at the same moment. Nothing was '
          'saved — check the roster and try again.',
    'not-found' =>
      'That rider is no longer on the roster. Refresh and try again.',
    'failed-precondition' =>
      'Firestore could not complete the change. Nothing was saved — try '
          'again.',
    'resource-exhausted' =>
      'Firestore is over its quota for today. The change was not saved.',
    'unauthenticated' =>
      'Your session has expired. Sign in again, then retry the change.',
    _ => 'The change was not saved. Try again, and tell a Super Admin if it '
        'keeps happening.',
  };
}
