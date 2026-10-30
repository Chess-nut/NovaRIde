import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/constants/firestore_collections.dart';
import 'package:novaride/core/data/family_firestore_payloads.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/features/guardian/domain/models/rider_location.dart';

abstract interface class FamilyRepository {
  factory FamilyRepository() = FirebaseFamilyRepository;

  Stream<FamilyConnectedRider?> watchRiderStatus();
  Stream<RiderLocation?> watchRiderLocation();
  Stream<List<FamilyIncident>> watchIncidentHistory();
  Stream<FamilyIncident?> watchActiveEmergency();
  Stream<FamilyUserProfile> watchUserProfile();
  Stream<List<FamilyMember>> watchFamilyMembers();
  Stream<List<FamilyPermission>> watchMyPermissions();
  Future<String> createInvite({String? invitedEmail});
  Future<void> acceptInvite(String code);
  Future<void> setMemberPermission(
    String memberUid,
    FamilyPermissionType permission,
    bool enabled,
  );
  Future<void> setNotificationSetting(String setting, bool enabled);
  Future<void> revokeMember(String memberUid);
  Future<void> leaveFamily();
  Future<void> signOut();
}

final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => FamilyRepository(),
);

class FirebaseFamilyRepository implements FamilyRepository {
  FirebaseFamilyRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  static const _permissionKeys = <FamilyPermissionType, String>{
    FamilyPermissionType.liveLocation: 'liveLocation',
    FamilyPermissionType.emergencyAlerts: 'emergencyAlerts',
    FamilyPermissionType.tripStatus: 'tripStatus',
    FamilyPermissionType.helmetStatus: 'helmetStatus',
    FamilyPermissionType.incidentHistory: 'incidentHistory',
  };
  static const _notificationKeys = <String>{
    'emergencyAlerts',
    'accidentDetection',
    'tripStarted',
    'riderOffline',
    'gpsSignalLost',
  };
  static const _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('A signed-in account is required for family data.');
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection(FirestoreCollections.users).doc(_uid);

  Stream<String?> _watchFamilyId() {
    final uid = _uid;
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            throw StateError('The signed-in account profile is missing.');
          }
          final value = snapshot.data()?['familyId'];
          if (value == null) return null;
          if (value is! String || value.trim().isEmpty) {
            throw FormatException('users/$uid has an invalid familyId.');
          }
          return value;
        });
  }

  Stream<FamilyMember?> _watchMember(String familyId, String uid) =>
      _firestore
          .collection(FirestoreCollections.families)
          .doc(familyId)
          .collection('members')
          .doc(uid)
          .snapshots()
          .map((snapshot) => snapshot.exists ? _memberFrom(snapshot) : null);

  Stream<Map<String, dynamic>?> _watchRiderDocument(String familyId) =>
      _firestore
          .collection(FirestoreCollections.riders)
          .where('authUid', isEqualTo: familyId)
          .limit(2)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.length > 1) {
              throw StateError(
                'More than one rider roster entry is linked to this family.',
              );
            }
            if (snapshot.docs.isEmpty) return null;
            return {
              ...snapshot.docs.single.data(),
              'id': snapshot.docs.single.id,
            };
          });

  @override
  Stream<FamilyConnectedRider?> watchRiderStatus() =>
      _switchMap(_watchFamilyId(), (familyId) {
        if (familyId == null) return Stream.value(null);
        return _switchMap(_watchMember(familyId, _uid), (member) {
          if (member == null || member.status != 'active') {
            return Stream.value(null);
          }
          if (!_canReadRiderDocuments(member.permissions)) {
            return Stream.error(
              StateError(
                'The rider has disabled one or more permissions required to view their status.',
              ),
            );
          }
          return _watchRiderDocument(familyId).map((data) {
            if (data == null) return null;
            final name = _requiredString(data, 'fullName', 'riders');
            final status = _statusFromWire(data['status']);
            return FamilyConnectedRider(
              id: _requiredString(data, 'id', 'riders'),
              name: name,
              relationship: 'Rider',
              avatarLetters: _initials(name),
              status: status,
              isCurrentlyRiding: status == FamilyRiderStatus.riding,
              activeEmergency: status == FamilyRiderStatus.accidentDetected,
            );
          });
        });
      });

  @override
  Stream<RiderLocation?> watchRiderLocation() =>
      _switchMap(_watchFamilyId(), (familyId) {
        if (familyId == null) return Stream.value(null);
        return _switchMap(_watchMember(familyId, _uid), (member) {
          if (member == null ||
              member.status != 'active' ||
              !_canReadRiderDocuments(member.permissions)) {
            return Stream.value(null);
          }
          return _switchMap(_watchRiderDocument(familyId), (rider) {
            if (rider == null) return Stream.value(null);
            final deviceId = rider['helmetId'];
            if (deviceId is! String || deviceId.trim().isEmpty) {
              return Stream.value(null);
            }
            return _firestore
                .collection(FirestoreCollections.devices)
                .doc(deviceId)
                .snapshots()
                .map(
                  (device) =>
                      _locationFromDevice(rider: rider, device: device),
                );
          });
        });
      });

  @override
  Stream<List<FamilyIncident>> watchIncidentHistory() =>
      _watchPermittedIncidents('incidentHistory');

  @override
  Stream<FamilyIncident?> watchActiveEmergency() =>
      _watchPermittedIncidents('emergencyAlerts').map((incidents) {
        for (final incident in incidents) {
          if (incident.status != 'resolved' &&
              incident.status != 'cancelled') {
            return incident;
          }
        }
        return null;
      });

  Stream<List<FamilyIncident>> _watchPermittedIncidents(
    String permission,
  ) => _switchMap(_watchFamilyId(), (familyId) {
    if (familyId == null) return Stream.value(const <FamilyIncident>[]);
    return _switchMap(_watchMember(familyId, _uid), (member) {
      if (member == null ||
          member.status != 'active' ||
          member.permissions[permission] != true ||
          member.permissions['liveLocation'] != true) {
        return Stream.value(const <FamilyIncident>[]);
      }
      return _switchMap(_watchRiderDocument(familyId), (rider) {
        if (rider == null) return Stream.value(const <FamilyIncident>[]);
        final riderId = rider['id'];
        if (riderId is! String || riderId.isEmpty) {
          throw FormatException('Linked rider has an invalid id.');
        }
        return _firestore
            .collection(FirestoreCollections.alerts)
            .where('riderId', isEqualTo: riderId)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map(_incidentFrom)
                  .toList(growable: false),
            );
      });
    });
  });

  @override
  Stream<FamilyUserProfile> watchUserProfile() {
    final uid = _uid;
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            throw StateError('The signed-in account profile is missing.');
          }
          final data = snapshot.data()!;
          final settings = data['notificationSettings'];
          final parsedSettings = <String, bool>{};
          if (settings != null) {
            if (settings is! Map) {
              throw FormatException(
                'users/$uid.notificationSettings must be a map.',
              );
            }
            for (final entry in settings.entries) {
              if (entry.key is! String ||
                  !_notificationKeys.contains(entry.key) ||
                  entry.value is! bool) {
                throw FormatException(
                  'users/$uid.notificationSettings contains an invalid entry.',
                );
              }
              parsedSettings[entry.key as String] = entry.value as bool;
            }
          }
          return FamilyUserProfile(
            uid: uid,
            name: _requiredString(data, 'fullName', 'users'),
            relationship: data['role'] == 'rider' ? 'Rider' : 'Family member',
            phoneNumber: data['phoneNumber'] as String? ?? '',
            email: _requiredString(data, 'email', 'users'),
            connectedRider: '',
            familyId: data['familyId'] as String?,
            notificationSettings: Map.unmodifiable(parsedSettings),
          );
        });
  }

  @override
  Stream<List<FamilyMember>> watchFamilyMembers() =>
      _switchMap(_watchFamilyId(), (familyId) {
        if (familyId == null) return Stream.value(const <FamilyMember>[]);
        return _firestore
            .collection(FirestoreCollections.families)
            .doc(familyId)
            .collection('members')
            .where('status', isEqualTo: 'active')
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map(_memberFrom)
                  .toList(growable: false),
            );
      });

  @override
  Stream<List<FamilyPermission>> watchMyPermissions() =>
      _switchMap(_watchFamilyId(), (familyId) {
        if (familyId == null) {
          return Stream.value(_permissionsFor(const {}));
        }
        return _watchMember(familyId, _uid).map(
          (member) => _permissionsFor(member?.permissions ?? const {}),
        );
      });

  @override
  Future<String> createInvite({String? invitedEmail}) async {
    final uid = _uid;
    final user = await _userRef.get();
    if (user.data()?['familyId'] != uid ||
        user.data()?['role'] != 'rider') {
      throw StateError('Only the rider who owns a family can create invites.');
    }

    final code = _generateInviteCode();
    final email = invitedEmail?.trim().toLowerCase();
    final invite = <String, Object?>{
      'familyId': uid,
      'invitedBy': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 1)),
      ),
      if (email != null && email.isNotEmpty) 'invitedEmail': email,
    };
    final ref = _firestore
        .collection(FirestoreCollections.familyInvites)
        .doc(code);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        throw StateError('Could not generate a unique family invite code.');
      }
      transaction.set(ref, invite);
    });
    return code;
  }

  @override
  Future<void> acceptInvite(String code) async {
    final uid = _uid;
    final authUser = _auth.currentUser!;
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) throw ArgumentError.value(code, 'code');
    final inviteRef = _firestore
        .collection(FirestoreCollections.familyInvites)
        .doc(cleanCode);
    final userRef = _userRef;

    await _firestore.runTransaction((transaction) async {
      final inviteSnapshot = await transaction.get(inviteRef);
      final userSnapshot = await transaction.get(userRef);
      if (!inviteSnapshot.exists || !userSnapshot.exists) {
        throw StateError('This invite is invalid or has expired.');
      }
      final invite = inviteSnapshot.data()!;
      final user = userSnapshot.data()!;
      if (user['role'] != 'guardian') {
        throw StateError('Only a guardian account can accept a family invite.');
      }
      final familyId = invite['familyId'];
      final expiry = _date(invite['expiresAt']);
      if (familyId is! String ||
          invite['status'] != 'pending' ||
          expiry == null ||
          !expiry.isAfter(DateTime.now())) {
        throw StateError('This invite is invalid or has expired.');
      }
      final invitedEmail = invite['invitedEmail'];
      final accountEmail = authUser.email?.trim().toLowerCase();
      if (invitedEmail is String &&
          invitedEmail.isNotEmpty &&
          invitedEmail != accountEmail) {
        throw StateError('This invite was issued for a different email.');
      }

      final familyRef = _firestore
          .collection(FirestoreCollections.families)
          .doc(familyId);
      final newMemberRef = familyRef.collection('members').doc(uid);
      final familySnapshot = await transaction.get(familyRef);
      final memberSnapshot = await transaction.get(newMemberRef);
      final existingFamilyId = user['familyId'];
      DocumentSnapshot<Map<String, dynamic>>? previousMember;
      if (existingFamilyId is String && existingFamilyId != familyId) {
        previousMember = await transaction.get(
          _firestore
              .collection(FirestoreCollections.families)
              .doc(existingFamilyId)
              .collection('members')
              .doc(uid),
        );
      }

      if (!familySnapshot.exists ||
          familySnapshot.data()?['ownerUid'] != familyId ||
          (memberSnapshot.exists &&
              memberSnapshot.data()?['status'] != 'revoked') ||
          (existingFamilyId is String &&
              existingFamilyId != familyId &&
              previousMember?.data()?['status'] != 'revoked')) {
        throw StateError(
          'This account is already connected to a family, or the invite is no longer available.',
        );
      }

      transaction.update(inviteRef, {
        'status': 'accepted',
        'acceptedBy': uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      final member = FamilyFirestorePayloads.member(
        uid: uid,
        role: 'guardian',
        displayName: (user['fullName'] as String?) ?? '',
        serverTimestamp: FieldValue.serverTimestamp(),
      );
      if (memberSnapshot.exists) {
        member.remove('createdAt');
        transaction.update(newMemberRef, member);
      } else {
        transaction.set(newMemberRef, member);
      }
      transaction.update(userRef, {
        'familyId': familyId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> setMemberPermission(
    String memberUid,
    FamilyPermissionType permission,
    bool enabled,
  ) async {
    final uid = _uid;
    final user = await _userRef.get();
    final familyId = user.data()?['familyId'];
    if (user.data()?['role'] != 'rider' || familyId != uid) {
      throw StateError('Only the rider who owns a family can change access.');
    }
    if (memberUid == uid) {
      throw ArgumentError.value(memberUid, 'memberUid');
    }
    final key = _permissionKeys[permission]!;
    await _firestore
        .collection(FirestoreCollections.families)
        .doc(uid)
        .collection('members')
        .doc(memberUid)
        .update({
          'permissions.$key': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> setNotificationSetting(String setting, bool enabled) async {
    if (!_notificationKeys.contains(setting)) {
      throw ArgumentError.value(setting, 'setting');
    }
    await _userRef.update({
      'notificationSettings.$setting': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> revokeMember(String memberUid) async {
    final uid = _uid;
    final user = await _userRef.get();
    if (user.data()?['role'] != 'rider' ||
        user.data()?['familyId'] != uid ||
        memberUid == uid) {
      throw StateError('Only the rider who owns a family can remove members.');
    }
    await _firestore
        .collection(FirestoreCollections.families)
        .doc(uid)
        .collection('members')
        .doc(memberUid)
        .update({
          'status': 'revoked',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> leaveFamily() async {
    final uid = _uid;
    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(_userRef);
      if (!userSnapshot.exists) {
        throw StateError('The signed-in account profile is missing.');
      }
      final user = userSnapshot.data()!;
      final familyId = user['familyId'];
      if (user['role'] != 'guardian' || familyId is! String) {
        throw StateError('This account is not a family guardian.');
      }
      final memberRef = _firestore
          .collection(FirestoreCollections.families)
          .doc(familyId)
          .collection('members')
          .doc(uid);
      final member = await transaction.get(memberRef);
      if (!member.exists || member.data()?['status'] != 'active') {
        throw StateError('This family connection is no longer active.');
      }
      transaction.update(memberRef, {
        'status': 'revoked',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(_userRef, {
        'familyId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _generateInviteCode() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => _inviteAlphabet[random.nextInt(_inviteAlphabet.length)],
    ).join();
  }

  RiderLocation? _locationFromDevice({
    required Map<String, dynamic> rider,
    required DocumentSnapshot<Map<String, dynamic>> device,
  }) {
    if (!device.exists) return null;
    final data = device.data()!;
    final latitude = _number(data['latitude'] ?? data['lat']);
    final longitude = _number(data['longitude'] ?? data['lng']);
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    final hasFix = data['gps_fix'] is bool
        ? data['gps_fix'] as bool
        : latitude != 0 || longitude != 0;
    if (!hasFix) return null;
    final explicitAddress = data['address'];
    final address = explicitAddress is String && explicitAddress.isNotEmpty
        ? explicitAddress
        : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    return RiderLocation(
      riderId: _requiredString(rider, 'id', 'riders'),
      latitude: latitude,
      longitude: longitude,
      speedKmh: _number(data['speed_kmh'] ?? data['speedKmh']),
      heading: _number(data['heading']),
      timestamp: _date(data['last_update'] ?? data['lastUpdate']),
      status: _statusFromWire(rider['status']).label,
      address: address,
    );
  }

  FamilyMember _memberFrom(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return FamilyMember(
      uid: _requiredString(data, 'uid', snapshot.reference.path),
      displayName: _requiredString(
        data,
        'displayName',
        snapshot.reference.path,
      ),
      role: _requiredString(data, 'role', snapshot.reference.path),
      status: _requiredString(data, 'status', snapshot.reference.path),
      permissions: _parsePermissions(data, snapshot.reference.path),
    );
  }

  FamilyIncident _incidentFrom(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final timestamp = _date(data['timestamp']);
    if (timestamp == null) {
      throw FormatException('${snapshot.reference.path} has no timestamp.');
    }
    final type = data['type']?.toString() ?? 'unknown';
    final title = switch (type) {
      'crash' => 'Accident detected',
      'sos' => 'SOS alert',
      'alcoholWarning' => 'Alcohol warning',
      'lowBattery' => 'Low battery',
      _ => type,
    };
    final lat = _number(data['lat'] ?? data['latitude']);
    final lng = _number(data['lng'] ?? data['longitude']);
    final gpsInfo = lat != null && lng != null
        ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
        : 'Unavailable';
    final status = data['status']?.toString() ?? 'open';
    return FamilyIncident(
      id: snapshot.id,
      title: title,
      location: data['address']?.toString() ?? 'Unavailable',
      timestamp: timestamp,
      status: status,
      severity: data['severity']?.toString() ?? 'unknown',
      riderStatus: status,
      incidentType: type,
      gpsInfo: gpsInfo,
      sosTriggered: type == 'sos',
      riderCancelledAlert: status == 'cancelled',
      durationLabel: data['duration']?.toString() ?? 'Unavailable',
    );
  }

  static FamilyRiderStatus _statusFromWire(Object? value) => switch (value) {
    'riding' => FamilyRiderStatus.riding,
    'emergency' => FamilyRiderStatus.accidentDetected,
    'offline' => FamilyRiderStatus.offline,
    'idle' || null => FamilyRiderStatus.idle,
    _ => throw FormatException('Unknown rider status: $value'),
  };

  static Map<String, bool> _parsePermissions(
    Map<String, dynamic> data,
    String path,
  ) {
    final raw = data['permissions'];
    if (raw is! Map) {
      throw FormatException('$path.permissions must be a map.');
    }
    final parsed = <String, bool>{};
    for (final key in FamilyFirestorePayloads.defaultPermissions.keys) {
      if (raw[key] is! bool) {
        throw FormatException('$path.permissions.$key must be a boolean.');
      }
      parsed[key] = raw[key] as bool;
    }
    return Map.unmodifiable(parsed);
  }

  static bool _canReadRiderDocuments(Map<String, bool> permissions) =>
      permissions['liveLocation'] == true &&
      permissions['tripStatus'] == true &&
      permissions['helmetStatus'] == true;

  static List<FamilyPermission> _permissionsFor(
    Map<String, bool> permissions,
  ) => [
    for (final entry in _permissionKeys.entries)
      FamilyPermission(
        type: entry.key,
        label: switch (entry.key) {
          FamilyPermissionType.liveLocation => 'Live Location',
          FamilyPermissionType.emergencyAlerts => 'Emergency Alerts',
          FamilyPermissionType.tripStatus => 'Trip Status',
          FamilyPermissionType.helmetStatus => 'Helmet Status',
          FamilyPermissionType.incidentHistory => 'Incident History',
        },
        enabled: permissions[entry.value] ?? false,
      ),
  ];

  static String _requiredString(
    Map<String, dynamic> data,
    String field,
    String path, {
    bool allowEmpty = false,
  }) {
    final value = data[field];
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('$path.$field must be a non-empty string.');
    }
    return value;
  }

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : null;

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words.first.isEmpty ? '' : words.first[0].toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

Stream<R> _switchMap<S, R>(
  Stream<S> source,
  Stream<R> Function(S value) convert,
) => Stream<R>.multi((controller) {
  StreamSubscription<S>? sourceSubscription;
  StreamSubscription<R>? innerSubscription;
  var sourceDone = false;
  var innerDone = true;
  var cancelled = false;
  var switchQueue = Future<void>.value();

  sourceSubscription = source.listen(
    (value) {
      innerDone = false;
      switchQueue = switchQueue.then((_) async {
        await innerSubscription?.cancel();
        if (cancelled) return;
        innerSubscription = convert(value).listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            innerDone = true;
            if (sourceDone) controller.close();
          },
        );
      }).catchError((Object error, StackTrace stackTrace) {
        controller.addError(error, stackTrace);
      });
    },
    onError: controller.addError,
    onDone: () {
      sourceDone = true;
      if (innerDone) controller.close();
    },
  );

  controller.onCancel = () async {
    cancelled = true;
    await sourceSubscription?.cancel();
    await switchQueue;
    await innerSubscription?.cancel();
  };
});
