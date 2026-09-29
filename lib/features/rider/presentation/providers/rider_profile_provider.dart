/// The signed-in rider's own profile.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/rider_profile.dart';

/// `riderProfiles/{uid}` for whoever is signed in.
///
/// Returns null data when nobody is signed in, or when the account is a
/// guardian — neither is an error, and a screen that asks for a rider
/// profile in either state has a routing bug rather than a data one.
final riderProfileProvider = StreamProvider<RiderProfile?>((ref) {
  final uid = ref.watch(authStateProvider).profile?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(riderProfileRepositoryProvider).watch(uid);
});
