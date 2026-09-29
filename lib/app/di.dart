/// The composition root: the providers whose implementation is chosen once,
/// for the whole app, rather than by whoever happens to need them.
///
/// Feature-local providers do not belong here. They live beside the feature
/// that owns them, the way `authStateProvider` lives in
/// `features/auth/presentation/providers/`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/firebase_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/rider/data/firestore_rider_profile_repository.dart';
import '../features/rider/domain/repositories/rider_profile_repository.dart';

/// The identity provider.
///
/// Phase 3 put the Firebase implementation behind it; until then this
/// threw, on purpose. A test overrides it at the [ProviderScope] with a
/// fake — nothing above this line knows Firebase exists.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

/// The rider half of a signed-in account, `riderProfiles/{uid}`.
///
/// Here rather than beside the feature because a test has to be able to
/// override it at the ProviderScope: without that, pumping any rider
/// screen constructs Firestore and fails on "no Firebase app".
final riderProfileRepositoryProvider = Provider<RiderProfileRepository>((ref) {
  return FirestoreRiderProfileRepository();
});
