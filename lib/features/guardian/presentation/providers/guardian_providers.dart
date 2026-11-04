/// What a signed-in guardian sees: their link, the rider behind it, that
/// rider's roster entry and alerts.
///
/// Chain: guardian uid → `guardianLinks/{uid}` → rider uid →
/// `users/{riderUid}` (name, phone) and `riders where authUid == riderUid`
/// (the roster id alerts are filed under) → `alerts where riderId == …`.
/// Each step is opened to a linked guardian by `firestore.rules`.
///
/// The helmet's live data is the same `helmetTelemetryProvider` the rider
/// app reads.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../rider/domain/entities/rider_alert.dart';
import '../../domain/entities/guardian_link.dart';

/// The rider this guardian follows, or null when not linked yet.
final myGuardianLinkProvider = StreamProvider<GuardianLink?>((ref) {
  final uid = ref.watch(authStateProvider).profile?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(guardianLinkRepositoryProvider).watchLinkOf(uid);
});

/// The followed rider's account: name and phone number.
final followedRiderAccountProvider =
    StreamProvider<FollowedRiderAccount?>((ref) {
  final riderUid = ref.watch(myGuardianLinkProvider).value?.riderUid;
  if (riderUid == null) return Stream.value(null);
  return ref.watch(guardianLinkRepositoryProvider).watchRiderAccount(riderUid);
});

/// The followed rider's roster entry, or null until operations links
/// their account to a helmet.
final followedRosterProvider = StreamProvider<LinkedRider?>((ref) {
  final riderUid = ref.watch(myGuardianLinkProvider).value?.riderUid;
  if (riderUid == null) return Stream.value(null);
  return ref.watch(riderAlertRepositoryProvider).watchLinkedRider(riderUid);
});

/// The followed rider's alerts, newest first (the newest 20).
final followedAlertsProvider = StreamProvider<List<RiderAlert>>((ref) {
  final riderId = ref.watch(followedRosterProvider).value?.riderId;
  if (riderId == null) return Stream.value(const []);
  return ref.watch(riderAlertRepositoryProvider).watchAlerts(riderId);
});

/// The crash or SOS still being worked, if there is one.
RiderAlert? activeEmergencyIn(List<RiderAlert> alerts) {
  for (final alert in alerts) {
    if (alert.isCritical && alert.isLive) return alert;
  }
  return null;
}

/// Counts for the safety summary, from the alerts loaded.
class SafetySummary {
  const SafetySummary({
    required this.crashes,
    required this.sos,
    required this.alcohol,
    required this.lastAlertAt,
    required this.total,
  });

  final int crashes;
  final int sos;
  final int alcohol;
  final int total;
  final DateTime? lastAlertAt;

  factory SafetySummary.of(List<RiderAlert> alerts) {
    int count(String type) => alerts.where((a) => a.type == type).length;
    DateTime? last;
    for (final a in alerts) {
      final t = a.timestamp;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    return SafetySummary(
      crashes: count('crash'),
      sos: count('sos'),
      alcohol: count('alcoholWarning'),
      total: alerts.length,
      lastAlertAt: last,
    );
  }

  /// "12 days since the last alert", "Last alert today", or "No alerts
  /// yet".
  String sinceLastAlert(DateTime now) {
    final last = lastAlertAt;
    if (last == null) return 'No alerts yet';
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
    if (days <= 0) return 'Last alert today';
    if (days == 1) return '1 day since the last alert';
    return '$days days since the last alert';
  }
}
