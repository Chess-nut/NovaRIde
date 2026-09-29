// A RiderProfileRepository that never touches Firestore.
//
// Every widget test that pumps a rider screen needs this: without it the
// provider builds the Firestore one and the test dies on "no Firebase
// app" — the same trap the auth repository had.

import 'dart:async';

import 'package:novaride/features/rider/domain/entities/rider_profile.dart';
import 'package:novaride/features/rider/domain/repositories/rider_profile_repository.dart';

class FakeRiderProfileRepository implements RiderProfileRepository {
  FakeRiderProfileRepository({this.profile});

  /// What [watch] emits. Null is the guardian case, and the moment
  /// before ensureProfile commits.
  final RiderProfile? profile;

  final List<String> calls = [];

  @override
  Stream<RiderProfile?> watch(String uid) {
    calls.add('watch:$uid');
    return Stream.value(profile);
  }
}
