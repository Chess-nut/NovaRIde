/// The signed-in rider's roster link and alerts.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/rider_alert.dart';

/// The roster entry linked to whoever is signed in, or null when nobody is
/// signed in or no Super Admin has linked this account yet.
///
/// A guardian is never linked to a roster entry (the rules refuse it), so
/// this is null for them without asking — the crash countdown that wraps
/// every screen is the rider's alone. A guardian reaches the rider they
/// follow through `followedRosterProvider` instead.
final linkedRiderProvider = StreamProvider<LinkedRider?>((ref) {
  final profile = ref.watch(authStateProvider).profile;
  if (profile == null || !profile.isRider) return Stream.value(null);
  return ref.watch(riderAlertRepositoryProvider).watchLinkedRider(profile.uid);
});

/// That rider's alerts, newest first. Empty while unlinked.
final riderAlertsProvider = StreamProvider<List<RiderAlert>>((ref) {
  final riderId = ref.watch(linkedRiderProvider).value?.riderId;
  if (riderId == null) return Stream.value(const []);
  return ref.watch(riderAlertRepositoryProvider).watchAlerts(riderId);
});
