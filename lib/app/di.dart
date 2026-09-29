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

/// The identity provider.
///
/// Phase 3 put the Firebase implementation behind it; until then this
/// threw, on purpose. A test overrides it at the [ProviderScope] with a
/// fake — nothing above this line knows Firebase exists.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});
