/// The composition root: the providers whose implementation is chosen once,
/// for the whole app, rather than by whoever happens to need them.
///
/// Phase 1 has one real entry and one deliberate hole. [authRepositoryProvider]
/// throws until Phase 3 puts the Firebase implementation behind it — a
/// throwing provider is better than a silent fake, because the day a screen
/// starts depending on it, the failure names the phase that owes it.
///
/// Feature-local providers do not belong here. They live beside the feature
/// that owns them, the way `authStateProvider` lives in
/// `features/auth/presentation/providers/`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/repositories/auth_repository.dart';

/// The identity provider.
///
/// Phase 3 overrides this at the [ProviderScope] in `main.dart`, or
/// replaces the body here, with the Firebase implementation. Until then any
/// read is a programming error, and says so.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError(
    'AuthRepository has no implementation yet — Phase 3 adds the Firebase '
    'one. Until then the router runs on the placeholder authStateProvider.',
  );
});
