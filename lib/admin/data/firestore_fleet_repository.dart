import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'
    show DatabaseEvent, FirebaseDatabase;
import 'package:flutter/foundation.dart';
import 'package:novaride/admin/data/fleet_geography.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/data/rtdb_fleet_merge.dart';
import 'package:novaride/shared/models/models.dart';

/// Cloud Firestore-backed fleet. Schema in `docs/FIRESTORE_SCHEMA.md`.
///
/// Four listeners feed three streams: `riders/`, `devices/`, `alerts/` and
/// the `history` collection group. Devices are joined to riders here — the
/// dashboard thinks in riders, the firmware thinks in helmets — and history
/// entries are stitched onto their alert so the pages see one [AlertEvent]
/// with its audit trail, exactly as the simulation hands it over.
///
/// Telemetry has a second source, and on the bench today it is the main
/// one. Helmets on the Realtime Database firmware write camelCase nodes
/// instead of Firestore `devices/`: `deviceStatus/{id}` (30 s heartbeat),
/// `devices/{id}/safety` (10 s sensors), `devices/{id}/tracking` (5-min
/// fix), `devices/{id}/latest` (fix on alerts) and the `trackingLogs/{id}`
/// and `gpsLogs/{id}` histories. When a [FirebaseDatabase] is passed, all of
/// them are listened to — the two `…Logs` per helmet and only their last
/// [kLogEntriesPerDevice] entries, never the roots whole — and merged by
/// `rtdb_fleet_merge.dart` into the same [HelmetTelemetry] list. For a
/// helmet present in both stores the fresher reading wins.
///
/// RTDB telemetry is published on its own. Firestore `devices/` is optional
/// extra data and the source of `assigned_rider_id`; a slow, empty or
/// refused `devices/` listener no longer hides the helmets RTDB can see.
///
/// This class is also the console's [HelmetFeed]: it hands the controller
/// each helmet's fix history, the crash / rider-check / alcohol / emergency
/// events the helmet reported in RTDB (which no Firestore alert covers on
/// that firmware), and the RTDB link's own health for the top bar.
///
/// Parsing is deliberately forgiving. A field that is missing or the wrong
/// type is absent — never a made-up reading; a document that cannot be read
/// at all is skipped with a `debugPrint`. One malformed write from a helmet
/// must never blank an operator's board mid-shift.
///
/// Roster writes run as transactions (see [addRider]) so that two operators
/// working at once cannot claim the same rider id or the same helmet, and
/// so that a console with no network fails fast instead of queueing a write
/// that the operator would see as saved. They use explicit field paths — the
/// helmet writes its own fields into the same documents, and the console
/// never erases one it does not know about.
class FirestoreFleetRepository implements FleetRepository, HelmetFeed {
  /// [database] is the Realtime Database helmet telemetry source; null
  /// leaves telemetry on Firestore alone. It must be built with an explicit
  /// `databaseURL` ([helmetDatabaseUrl]) — see there.
  FirestoreFleetRepository({
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _rtdb = database {
    _start();
  }

  /// The project's Realtime Database. Passed explicitly because the
  /// console's config (`assets/config/firebase.json`) has no `databaseURL`,
  /// and without one the SDK resolves to the us-central1 host and silently
  /// returns nothing. This database is in asia-southeast1. Same value as the
  /// rider app's `helmetDatabaseUrl`; the console does not import from
  /// `lib/features/`.
  static const helmetDatabaseUrl =
      'https://novaride-7a68c-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// How long an RTDB fix still counts as current: [kFixCurrentFor]. Older
  /// than that, speed is not shown and the map marks the dot stale.
  static const rtdbFixStaleAfter = kFixCurrentFor;

  /// "Current" depends on the clock as well as the data, and a helmet that
  /// stops writing sends nothing to say so. The RTDB view is recomputed on
  /// this beat so a fix ages out on screen without waiting for a write.
  static const _rtdbRefresh = Duration(seconds: 30);

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
  final FirebaseDatabase? _rtdb;

  final _ridersCtrl = StreamController<List<Rider>>.broadcast();
  final _telemetryCtrl = StreamController<List<HelmetTelemetry>>.broadcast();
  final _alertsCtrl = StreamController<List<AlertEvent>>.broadcast();
  final _connectionCtrl = StreamController<FleetConnection>.broadcast();
  final _rtdbLinkCtrl = StreamController<RtdbLink>.broadcast();
  final _fixHistoryCtrl =
      StreamController<Map<String, List<HelmetFix>>>.broadcast();
  final _helmetEventsCtrl = StreamController<List<HelmetEvent>>.broadcast();

  List<Rider> _riders = const [];
  List<HelmetTelemetry> _telemetry = const [];
  List<AlertEvent> _alerts = const [];
  FleetConnection _connection = FleetConnection.connecting;
  late RtdbLink _rtdbLink = _rtdb == null
      ? RtdbLink.notConfigured
      : RtdbLink.connecting;
  Map<String, List<HelmetFix>> _fixHistory = const {};
  List<HelmetEvent> _helmetEvents = const [];

  /// Raw inputs kept so either side of a join can be recomputed when the
  /// other changes.
  QuerySnapshot<Map<String, dynamic>>? _deviceDocs;
  List<AlertEvent> _bareAlerts = const [];
  Map<String, List<AlertAction>> _historyByAlert = const {};

  /// Realtime Database node values by device id, exactly as delivered:
  /// `deviceStatus/{id}`, `devices/{id}` (with `latest`, `tracking`,
  /// `safety`), and the last entries of `trackingLogs/{id}` and
  /// `gpsLogs/{id}`.
  Map<String, Object?> _rtdbStatus = const {};
  Map<String, Object?> _rtdbDevices = const {};
  final Map<String, Object?> _trackingLogs = {};
  final Map<String, Object?> _gpsLogs = {};

  /// Remembers values across RTDB snapshots: event transitions, SW-420.
  final RtdbHelmetTracker _tracker = RtdbHelmetTracker();

  /// RTDB listener errors by listener name, for the link chip.
  final Map<String, Object> _rtdbErrors = {};

  /// `.info/connected`: null until the SDK first says, then its answer.
  bool? _rtdbConnected;

  bool _ridersLoaded = false;
  bool _telemetryLoaded = false;
  bool _alertsLoaded = false;
  bool _disposed = false;

  /// Either telemetry source has answered — with data or with an error.
  /// Telemetry is "loaded" on the first answer from either, not both.
  bool _devicesAnswered = false;
  bool _rtdbAnswered = false;

  final Map<String, StreamSubscription<dynamic>> _subs = {};
  final Map<String, Timer> _retries = {};
  final Map<String, Duration> _backoff = {};
  final Map<String, void Function()> _restarts = {};
  Timer? _firstSnapshotTimer;
  Timer? _rtdbFirstAnswerTimer;
  Timer? _rtdbRefreshTimer;

  @override
  FleetSource get source => FleetSource.firestore;

  // --------------------------------------------------------------- streams

  @override
  Stream<List<Rider>> watchRiders() =>
      _replaying(() => _ridersLoaded ? _riders : null, _ridersCtrl.stream);

  @override
  Stream<List<HelmetTelemetry>> watchTelemetry() => _replaying(
    () => _telemetryLoaded ? _telemetry : null,
    _telemetryCtrl.stream,
  );

  @override
  Stream<List<AlertEvent>> watchAlerts() =>
      _replaying(() => _alertsLoaded ? _alerts : null, _alertsCtrl.stream);

  @override
  Stream<FleetConnection> watchConnection() =>
      _replaying(() => _connection, _connectionCtrl.stream);

  @override
  Stream<RtdbLink> watchRtdbLink() =>
      _replaying(() => _rtdbLink, _rtdbLinkCtrl.stream);

  @override
  Stream<Map<String, List<HelmetFix>>> watchFixHistory() =>
      _replaying(() => _fixHistory, _fixHistoryCtrl.stream);

  @override
  Stream<List<HelmetEvent>> watchHelmetEvents() =>
      _replaying(() => _helmetEvents, _helmetEventsCtrl.stream);

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
        _setConnection(
          const FleetConnection(
            FleetConnectionState.disconnected,
            'No response from Firestore — check the network and the rules.',
          ),
        );
      }
    });
    _listenRiders();
    _listenDevices();
    _listenAlerts();
    _listenHistory();
    if (_rtdb != null) {
      _rtdbFirstAnswerTimer = Timer(_firstSnapshotTimeout, () {
        if (_rtdbLink.state == RtdbLinkState.connecting) {
          _setRtdbLink(
            const RtdbLink(
              RtdbLinkState.offline,
              'No answer from Realtime Database in 15 s — check the '
              'network. Helmet telemetry will not update.',
            ),
          );
        }
      });
      _rtdbRefreshTimer = Timer.periodic(_rtdbRefresh, (_) {
        if (_rtdbAnswered) _publishTelemetry();
      });
      _listenRtdbConnected();
      _listenRtdbStatus();
      _listenRtdbPositions();
    }
  }

  void _listenRiders() {
    _subscribe(
      'riders',
      _db.collection('riders').snapshots(includeMetadataChanges: true),
      (QuerySnapshot<Map<String, dynamic>> snap) {
        _riders = [for (final doc in snap.docs) ?_parse(doc, _riderFrom)];
        _ridersLoaded = true;
        _ridersCtrl.add(_riders);
        // Riders are the join key for devices and the name source for
        // alerts and helmet events, so all three are refreshed off the
        // same snapshot.
        _publishTelemetry();
        _publishHelmetEvents();
        _publishAlerts();
        _reportMetadata(snap.metadata);
      },
      restart: _listenRiders,
    );
  }

  void _listenDevices() {
    _subscribe(
      'devices',
      _db.collection('devices').snapshots(includeMetadataChanges: true),
      (QuerySnapshot<Map<String, dynamic>> snap) {
        _deviceDocs = snap;
        _devicesAnswered = true;
        _publishTelemetry();
        _publishHelmetEvents();
        _reportMetadata(snap.metadata);
      },
      restart: _listenDevices,
      onFailure: () {
        // A refused or broken devices/ listener is an answer too: RTDB
        // helmets are shown without it rather than not at all.
        _devicesAnswered = true;
        _publishTelemetry();
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
        _bareAlerts = [for (final doc in snap.docs) ?_parse(doc, _alertFrom)];
        _alertsLoaded = true;
        _publishAlerts();
        _reportMetadata(snap.metadata);
      },
      restart: _listenAlerts,
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
      restart: _listenHistory,
    );
  }

  // ------------------------------------------------- Realtime Database

  /// RTDB listeners do not drive the FIRESTORE pill — riders and alerts
  /// depend on Firestore alone. They drive the RTDB chip instead
  /// ([watchRtdbLink]); a refusal is shown there, logged and retried.
  void _listenRtdbConnected() {
    _subscribe(
      'rtdbConnected',
      _rtdb!.ref('.info/connected').onValue,
      (DatabaseEvent event) {
        final value = event.snapshot.value;
        if (value is bool) _rtdbConnected = value;
        _updateRtdbLink();
      },
      affectsConnection: false,
      rtdb: true,
      restart: _listenRtdbConnected,
    );
  }

  void _listenRtdbStatus() {
    _subscribe(
      'deviceStatus',
      _rtdb!.ref('deviceStatus').onValue,
      (DatabaseEvent event) {
        _rtdbStatus = _rtdbChildren(event.snapshot.value);
        _onRtdbChanged();
      },
      affectsConnection: false,
      rtdb: true,
      restart: _listenRtdbStatus,
    );
  }

  /// `devices/` whole: per helmet it holds `latest`, `tracking` and
  /// `safety`, three small nodes overwritten in place, so the root stays
  /// small however long the helmets run.
  void _listenRtdbPositions() {
    _subscribe(
      'rtdbDevices',
      _rtdb!.ref('devices').onValue,
      (DatabaseEvent event) {
        _rtdbDevices = _rtdbChildren(event.snapshot.value);
        _onRtdbChanged();
      },
      affectsConnection: false,
      rtdb: true,
      restart: _listenRtdbPositions,
    );
  }

  /// One listener per helmet on `trackingLogs/{id}` and `gpsLogs/{id}`,
  /// each `limitToLast(kLogEntriesPerDevice)`. Never the roots: both are
  /// append-only push lists that grow every 5 minutes per helmet, forever.
  /// Called whenever the set of known helmets may have changed.
  void _syncLogListeners() {
    final ids = {..._rtdbStatus.keys, ..._rtdbDevices.keys};
    for (final id in ids) {
      for (final root in const ['trackingLogs', 'gpsLogs']) {
        final name = '$root:$id';
        if (_subs.containsKey(name) || _retries.containsKey(name)) continue;
        _listenLog(root, id);
      }
    }
    // A helmet deleted from the database takes its listeners with it.
    for (final name in _subs.keys.toList()) {
      final split = name.indexOf(':');
      if (split < 0) continue;
      final root = name.substring(0, split);
      if (root != 'trackingLogs' && root != 'gpsLogs') continue;
      final id = name.substring(split + 1);
      if (ids.contains(id)) continue;
      _subs.remove(name)?.cancel();
      _retries.remove(name)?.cancel();
      _restarts.remove(name);
      _rtdbErrors.remove(name);
      _trackingLogs.remove(id);
      _gpsLogs.remove(id);
      _tracker.forget(id);
    }
  }

  void _listenLog(String root, String id) {
    final target = root == 'trackingLogs' ? _trackingLogs : _gpsLogs;
    void listen() => _subscribe(
      '$root:$id',
      _rtdb!.ref('$root/$id').limitToLast(kLogEntriesPerDevice).onValue,
      (DatabaseEvent event) {
        target[id] = event.snapshot.value;
        _onRtdbChanged(syncLogs: false);
      },
      affectsConnection: false,
      rtdb: true,
      restart: () => _listenLog(root, id),
    );
    listen();
  }

  /// Every RTDB delivery lands here: remember transitions, then republish
  /// telemetry, fix history and helmet events.
  void _onRtdbChanged({bool syncLogs = true}) {
    _rtdbAnswered = true;
    _rtdbFirstAnswerTimer?.cancel();
    if (syncLogs) _syncLogListeners();
    var eventsChanged = false;
    for (final id in _rtdbIds) {
      eventsChanged |= _tracker.observe(
        id,
        status: _rtdbStatus[id],
        device: _rtdbDevices[id],
        trackingLogs: _trackingLogs[id],
        gpsLogs: _gpsLogs[id],
      );
    }
    _publishTelemetry();
    _publishFixHistory();
    if (eventsChanged || _helmetEvents.isEmpty) _publishHelmetEvents();
    _updateRtdbLink();
  }

  Set<String> get _rtdbIds => {
    ..._rtdbStatus.keys,
    ..._rtdbDevices.keys,
    ..._trackingLogs.keys,
    ..._gpsLogs.keys,
  };

  /// `{id: value}` from an RTDB node. Values are kept raw for the merge.
  static Map<String, Object?> _rtdbChildren(Object? value) {
    if (value is Map) return {for (final e in value.entries) '${e.key}': e.value};
    if (value is List) {
      // RTDB returns a List for a node whose keys are 0, 1, 2…; a device
      // id like that is unlikely but is not an error.
      return {
        for (var i = 0; i < value.length; i++)
          if (value[i] != null) '$i': value[i],
      };
    }
    return const {};
  }

  /// LIVE, DENIED, OFFLINE or CONNECTING, from the listeners' own errors
  /// and `.info/connected`. A refusal outranks everything: it will not fix
  /// itself, and the operator needs to know whom to ask.
  void _updateRtdbLink() {
    if (_rtdb == null) return;
    Object? denied;
    Object? failed;
    for (final error in _rtdbErrors.values) {
      if (_isPermissionDenied(error)) {
        denied ??= error;
      } else {
        failed ??= error;
      }
    }
    final RtdbLink link;
    if (denied != null) {
      link = RtdbLink(
        RtdbLinkState.denied,
        'Realtime Database refused to read helmet data '
        '(${_errorText(denied)}). The RTDB rules (database.rules.json) are '
        'not in this repository — a project owner must allow signed-in '
        'console operators to read deviceStatus, devices, trackingLogs and '
        'gpsLogs.',
      );
    } else if (failed != null) {
      link = RtdbLink(
        RtdbLinkState.offline,
        'Realtime Database error: ${_errorText(failed)}. Retrying.',
      );
    } else if (_rtdbConnected == false && _rtdbAnswered) {
      link = const RtdbLink(
        RtdbLinkState.offline,
        'Realtime Database connection lost — showing the last readings '
        'received. Reconnecting.',
      );
    } else if (_rtdbAnswered) {
      link = const RtdbLink(
        RtdbLinkState.live,
        'Receiving helmet telemetry from Realtime Database '
        '(asia-southeast1).',
      );
    } else {
      return; // still connecting; the first-answer timer reports silence
    }
    _setRtdbLink(link);
  }

  void _setRtdbLink(RtdbLink link) {
    if (_disposed) return;
    if (_rtdbLink.state == link.state && _rtdbLink.message == link.message) {
      return;
    }
    _rtdbLink = link;
    _rtdbLinkCtrl.add(link);
  }

  static bool _isPermissionDenied(Object error) {
    final text = error is FirebaseException
        ? '${error.code} ${error.message}'
        : '$error';
    return text.toLowerCase().contains('permission');
  }

  static String _errorText(Object error) => error is FirebaseException
      ? (error.message?.isNotEmpty ?? false)
            ? '${error.code}: ${error.message}'
            : error.code
      : '$error';

  /// Wires one listener with restart-on-error. Each listener backs off on
  /// its own, so a missing index on `history` cannot take `riders` down.
  ///
  /// [rtdb] listeners report into the RTDB chip; [onFailure] runs after an
  /// error is recorded, for listeners whose silence would block a view.
  void _subscribe<T>(
    String name,
    Stream<T> stream,
    void Function(T snapshot) onData, {
    required void Function() restart,
    bool affectsConnection = true,
    bool rtdb = false,
    void Function()? onFailure,
  }) {
    if (_disposed) return;
    _restarts[name] = restart;
    _subs[name]?.cancel();
    _subs[name] = stream.listen(
      (snapshot) {
        _backoff.remove(name);
        if (rtdb && _rtdbErrors.remove(name) != null) _updateRtdbLink();
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
        if (rtdb) {
          _rtdbErrors[name] = error;
          _rtdbFirstAnswerTimer?.cancel();
          // An error is an answer: telemetry stops waiting for RTDB.
          _rtdbAnswered = true;
          _updateRtdbLink();
          _publishTelemetry();
        }
        onFailure?.call();
        _subs.remove(name)?.cancel();
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
      _retries.remove(name);
      _restarts[name]?.call();
    });
  }

  /// Snapshot metadata is the honest signal: a snapshot served from cache
  /// means the SDK could not reach the server, whether or not it has said so.
  void _reportMetadata(SnapshotMetadata metadata) {
    _firstSnapshotTimer?.cancel();
    if (metadata.isFromCache) {
      _setConnection(
        const FleetConnection(
          FleetConnectionState.disconnected,
          'Showing cached data — Firestore is unreachable.',
        ),
      );
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
    if (error is FirebaseException && error.plugin == 'firebase_database') {
      return error.code == 'permission-denied'
          ? 'Realtime Database denied access — RTDB helmet telemetry will '
                'not show.'
          : 'Realtime Database error: ${error.code}';
    }
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

  /// Firestore `devices/` (if it has answered) and the RTDB helmets, joined
  /// by device id, case-insensitively. A helmet in both stores keeps
  /// whichever reading is newer.
  ///
  /// Either source alone is enough to publish: RTDB helmets no longer wait
  /// for Firestore `devices/`, which is only extra telemetry and the
  /// source of `assigned_rider_id`. Telemetry counts as loaded once either
  /// source has answered, with data or with an error.
  void _publishTelemetry() {
    if (_disposed) return;
    if (!_telemetryLoaded) {
      _telemetryLoaded =
          _devicesAnswered || (_rtdb != null && _rtdbAnswered);
      if (!_telemetryLoaded) return;
    }
    final byDevice = <String, HelmetTelemetry>{};
    final assignedByDevice = _assignments();
    for (final doc in _deviceDocs?.docs ?? const []) {
      final t = _parse(doc, _telemetryFrom);
      if (t != null) byDevice[doc.id.toUpperCase()] = t;
    }
    final now = DateTime.now();
    for (final id in _rtdbIds) {
      final key = id.toUpperCase();
      final HelmetTelemetry? t;
      try {
        t = mergeFleetNodes(
          deviceId: id,
          riderId: _riderForDevice(id, assignedByDevice[key])?.id,
          status: _rtdbStatus[id],
          device: _rtdbDevices[id],
          trackingLogs: _trackingLogs[id],
          gpsLogs: _gpsLogs[id],
          now: now,
          sw420ChangedAt: _tracker.sw420ChangedAt(id),
        );
      } catch (error) {
        debugPrint('FirestoreFleetRepository: skipped RTDB $id: $error');
        continue;
      }
      if (t == null) continue;
      final existing = byDevice[key];
      if (existing == null || !_isOlder(t, existing)) byDevice[key] = t;
    }
    _telemetry = byDevice.values.toList();
    _telemetryCtrl.add(_telemetry);
  }

  /// `assigned_rider_id` by upper-cased device id, from Firestore
  /// `devices/` — empty until (or unless) that listener answers.
  Map<String, String?> _assignments() => {
    for (final doc in _deviceDocs?.docs ?? const [])
      doc.id.toUpperCase(): _str(doc.data(), [
        'assigned_rider_id',
        'assignedRiderId',
      ]),
  };

  /// Every real fix per helmet, from all its RTDB nodes.
  void _publishFixHistory() {
    if (_disposed) return;
    final out = <String, List<HelmetFix>>{};
    for (final id in _rtdbIds) {
      try {
        final fixes = fixHistoryFromNodes(
          status: _rtdbStatus[id],
          device: _rtdbDevices[id],
          trackingLogs: _trackingLogs[id],
          gpsLogs: _gpsLogs[id],
        );
        if (fixes.isNotEmpty) out[id] = fixes;
      } catch (error) {
        debugPrint('FirestoreFleetRepository: no fix history for $id: $error');
      }
    }
    _fixHistory = out;
    _fixHistoryCtrl.add(out);
  }

  /// The tracker's events, joined to the roster for a rider id and name.
  void _publishHelmetEvents() {
    if (_disposed || _rtdb == null) return;
    final assigned = _assignments();
    _helmetEvents = [
      for (final e in _tracker.events)
        () {
          final rider = _riderForDevice(
            e.deviceId,
            assigned[e.deviceId.toUpperCase()],
          );
          return e.withRider(rider?.id, rider?.fullName);
        }(),
    ];
    _helmetEventsCtrl.add(_helmetEvents);
  }

  /// A reading with no timestamp is older than one with any.
  static bool _isOlder(HelmetTelemetry a, HelmetTelemetry b) {
    final at = a.lastUpdate;
    final bt = b.lastUpdate;
    if (bt == null) return false;
    return at == null || at.isBefore(bt);
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
      status:
          _enum(RiderStatus.values, _str(d, ['status'])) ?? RiderStatus.idle,
      isActive: _bool(d, ['isActive', 'is_active']) ?? true,
      registeredAt:
          _date(d, ['registeredAt', 'registered_at', 'createdAt']) ??
          DateTime.now(),
      authUid: _str(d, ['authUid']),
    );
  }

  /// The rider a device belongs to: by an explicit assignment on its
  /// `devices/` document, else by the rider whose helmet serial is the id.
  Rider? _riderForDevice(String deviceId, String? assigned) => assigned != null
      ? (_riderById(assigned) ?? _riderByHelmet(deviceId))
      : _riderByHelmet(deviceId);

  /// A device with no rider is still telemetry, with a null `riderId`: a
  /// helmet transmitting with nobody assigned is a state the operator sees.
  ///
  /// No reading has a default. A missing speed, battery or timestamp is
  /// null and shows as a dash — never 0, never "now".
  ///
  /// Field names cover both the schema's spelling and what the
  /// `USE_FIRESTORE 1` firmware actually writes (`alcohol_alert`,
  /// `alcohol_raw`, `alcohol_voltage`, `state`).
  HelmetTelemetry? _telemetryFrom(String deviceId, Map<String, dynamic> d) {
    final assigned = _str(d, ['assigned_rider_id', 'assignedRiderId']);
    final rawLat = _num(d, ['latitude', 'lat']);
    final rawLng = _num(d, ['longitude', 'lng', 'lon']);
    final real = isRealPosition(rawLat, rawLng);
    final lastUpdate = _date(d, [
      'last_update',
      'lastUpdate',
      'last_seen',
      'lastSeen',
    ]);
    return HelmetTelemetry(
      riderId: _riderForDevice(deviceId, assigned)?.id,
      deviceId: deviceId,
      speedKmh: _num(d, ['speed_kmh', 'speedKmh', 'speed']),
      // No default: absent is "not measured", not "not detected".
      alcoholDetected: _bool(d, [
        'alcohol_detected',
        'alcoholDetected',
        'alcohol_alert',
      ]),
      alcoholRawIndex: _num(d, ['alcohol_raw', 'alcoholRaw']),
      mq3Voltage: _num(d, ['alcohol_voltage']),
      batteryPct: _num(d, [
        'battery_pct',
        'batteryPct',
        'battery',
      ])?.round().clamp(0, 100),
      gpsFix: (_bool(d, ['gps_fix', 'gpsFix']) ?? true) && real,
      // A pre-lock 0 is not a position, so it is not plotted.
      lat: real ? rawLat : null,
      lng: real ? rawLng : null,
      fixAt: real ? lastUpdate : null,
      positionSource: real ? PositionSource.firestore : null,
      safetyEvent: _str(d, ['state', 'safetyEvent']),
      lastUpdate: lastUpdate,
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
      lat: point?.$1,
      lng: point?.$2,
      // Only an address the document carries. Without one the controller
      // describes the position — or says there is none. Never a district
      // street invented from 0,0.
      address: _str(d, ['address']) ?? '',
      deviceId: _str(d, ['deviceId', 'device_id']),
      timestamp:
          _date(d, ['timestamp', 'created_at', 'createdAt']) ?? DateTime.now(),
      status:
          _enum(AlertStatus.values, _str(d, ['status'])) ?? AlertStatus.open,
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

  /// `lat`/`lng` fields, a `location` GeoPoint, or a `location` map — or
  /// null when the alert carries no real position. A crash with no GPS fix
  /// is sent with no location (FIRMWARE_CONTRACT.md §3.1); it used to be
  /// read here as 0,0, which put it in Sampaloc.
  static (double, double)? _point(Map<String, dynamic> d) {
    (double, double)? real(double? lat, double? lng) =>
        isRealPosition(lat, lng) ? (lat!, lng!) : null;

    final lat = _num(d, ['lat', 'latitude']);
    final lng = _num(d, ['lng', 'longitude', 'lon']);
    if (lat != null && lng != null) return real(lat, lng);

    final location = d['location'];
    if (location is GeoPoint) {
      return real(location.latitude, location.longitude);
    }
    if (location is Map) {
      final map = location.cast<String, dynamic>();
      return real(
        _num(map, ['lat', 'latitude']),
        _num(map, ['lng', 'longitude', 'lon']),
      );
    }
    return null;
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
          _str(current.data() ?? const {}, ['helmetId', 'helmet_id']) ?? '';

      final pairing = await _readPairing(tx, rider.helmetId);
      if (pairing.holder != null && pairing.holder != rider.id) {
        return _refuse(
          'Helmet ${rider.helmetId} is assigned to ${pairing.holder}. '
          'Choose a different helmet.',
        );
      }
      final releasing =
          previousHelmet.isNotEmpty &&
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
        ? _str(snapshot.data() ?? const {}, [
            'assigned_rider_id',
            'assignedRiderId',
          ])
        : null;
    return (ref: ref, holder: holder);
  }

  /// The console's side of `devices/`: the pairing fields and nothing else.
  /// Merge, because the document may already hold the helmet's telemetry —
  /// or may not exist yet, when a rider is registered before their helmet
  /// first reports in.
  void _writePairing(Transaction tx, String helmetId, String riderId) {
    tx.set(_db.collection('devices').doc(helmetId), {
      'assigned_rider_id': riderId,
      'paired_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      debugPrint(
        'FirestoreFleetRepository: write refused — '
        '${error.plugin}/${error.code}: ${error.message}',
      );
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
  Future<String> linkAppAccount(String riderId, String username) => _guard(
    () async {
      final key = username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
      // usernames/ is the one index anyone may `get`: it is how login
      // turns a username into an email, and here how a username becomes
      // the uid to link.
      final claim = await _db.collection('usernames').doc(key).get();
      final uid = _str(claim.data() ?? const {}, ['uid']);
      if (uid == null) {
        throw FleetWriteException(
          'No app account is called @$key. Check the spelling with the rider.',
        );
      }
      for (final r in _riders) {
        if (r.id != riderId && r.authUid == uid) {
          throw FleetWriteException(
            '@$key is already linked to ${r.id}. Unlink it there first.',
          );
        }
      }
      try {
        await _db.collection('riders').doc(riderId).update({
          'authUid': uid,
          'authLinkedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (error) {
        // The rules refuse an account whose role is not rider: a guardian
        // linked here would read this rider's alerts.
        if (error.code == 'permission-denied') {
          throw FleetWriteException(
            '@$key was not linked: only a rider\'s own account can be '
            'linked, and only by a Super Admin.',
          );
        }
        rethrow;
      }
      return _str(claim.data()!, ['email']) ?? '@$key';
    },
  );

  @override
  Future<void> unlinkAppAccount(String riderId) => _guard(
    () => _db.collection('riders').doc(riderId).update({
      'authUid': FieldValue.delete(),
      'authLinkedAt': FieldValue.delete(),
    }),
  );

  @override
  Future<void> setRiderStatus(String riderId, RiderStatus status) => _guard(
    () => _db.collection('riders').doc(riderId).update({'status': status.name}),
  );

  /// Status change and audit entry go in one batch so neither can land
  /// without the other. `at` is the server clock: response-time metrics are
  /// the study's evidence, and operator machines are not a trustworthy
  /// source for them. The `<status>At` stamp on the alert itself lets the
  /// Reports tab query response times without reading every history entry.
  @override
  Future<void> transitionAlert(String alertId, AlertAction action) =>
      _guard(() {
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
      });

  /// Creates `alerts/{event.id}` — `{deviceId}_{serverTimeMs}` — in one
  /// transaction: read it, and write it only if nobody has. Two consoles
  /// opening the same helmet event therefore produce one alert, and the
  /// second simply resolves to the id the first created.
  ///
  /// The document satisfies the helmet branch of the alerts create rule
  /// (`isHelmetAlert` in firestore.rules: `riderId`, `deviceId`, `type`,
  /// lowercase `severity`, `status: open`, a server `timestamp`, a GeoPoint
  /// `location` or none, no lifecycle stamps), which is what both the Super
  /// Admin branch and the dispatcher branch (`isOpenedFromHelmet`, which
  /// also checks the id against `deviceId` + `helmetEventAt`) accept.
  ///
  /// `timestamp` is when it was opened — the board and the response-time
  /// metrics run from the moment an operator took it on. When the helmet
  /// reported it is kept in `helmetEventAt` (epoch ms, the RTDB server
  /// clock). The rider's status is not written: the console derives
  /// "emergency" from the open alert itself.
  @override
  Future<String> openHelmetEventAsAlert(
    HelmetEvent event, {
    required String actorName,
  }) async {
    final riderId = event.riderId;
    if (riderId == null || riderId.isEmpty) {
      throw FleetWriteException(
        'Helmet ${event.deviceId} is not paired to a rider, and an alert '
        'needs one. Pair the helmet in User Management first.',
      );
    }
    final ref = _db.collection('alerts').doc(event.id);
    try {
      await _db.runTransaction<void>((tx) async {
        final existing = await tx.get(ref);
        if (existing.exists) return;
        tx.set(ref, {
          'riderId': riderId,
          'deviceId': event.deviceId,
          'type': event.kind.alertType.name,
          'severity': event.kind.severity,
          'status': AlertStatus.open.name,
          'timestamp': FieldValue.serverTimestamp(),
          if (event.hasPosition) 'location': GeoPoint(event.lat!, event.lng!),
          'source': helmetAlertSource,
          'helmetEventAt': event.at.millisecondsSinceEpoch,
          'helmetEventKind': event.kind.name,
          'helmetDetail': event.detail,
          'openedBy': actorName,
        });
      });
      return event.id;
    } on FirebaseException catch (error) {
      debugPrint(
        'FirestoreFleetRepository: open-as-alert refused — '
        '${error.plugin}/${error.code}: ${error.message}',
      );
      if (error.code == 'permission-denied') {
        throw const FleetWriteException(
          'Firestore refused to open the alert. Only Super Admins and '
          'dispatchers may, and the rules that allow dispatchers '
          '(isOpenedFromHelmet in firestore.rules) must be deployed.',
        );
      }
      throw FleetWriteException(messageForWriteCode(error.code));
    } catch (error, stack) {
      debugPrint('FirestoreFleetRepository: open-as-alert threw $error\n$stack');
      throw const FleetWriteException(
        'The alert was not created. Try again, and tell a Super Admin if it '
        'keeps happening.',
      );
    }
  }

  /// `source` on an alert opened from a helmet event.
  static const helmetAlertSource = 'helmet-rtdb';

  @override
  void dispose() {
    _disposed = true;
    _firstSnapshotTimer?.cancel();
    _rtdbFirstAnswerTimer?.cancel();
    _rtdbRefreshTimer?.cancel();
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
    _rtdbLinkCtrl.close();
    _fixHistoryCtrl.close();
    _helmetEventsCtrl.close();
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
    _ =>
      'The change was not saved. Try again, and tell a Super Admin if it '
          'keeps happening.',
  };
}
