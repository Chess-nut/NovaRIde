/// The rider's people: guardians in the app, their invite codes, and
/// phone-only contacts. Each is empty while nobody is signed in.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../guardian/domain/entities/guardian_link.dart';
import '../../domain/entities/emergency_contact.dart';

/// Guardians following the signed-in rider, oldest first.
final riderGuardiansProvider = StreamProvider<List<GuardianLink>>((ref) {
  final uid = ref.watch(authStateProvider).profile?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(guardianLinkRepositoryProvider).watchGuardiansOf(uid);
});

/// The rider's invite codes, newest first, expired ones included — the
/// screen hides those, and shows the newest live one.
final riderInvitesProvider = StreamProvider<List<GuardianInvite>>((ref) {
  final uid = ref.watch(authStateProvider).profile?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(guardianLinkRepositoryProvider).watchInvitesOf(uid).map(
        (invites) => [...invites]..sort((a, b) =>
            (b.createdAt ?? DateTime(9999)).compareTo(a.createdAt ?? DateTime(9999))),
      );
});

/// Phone-only emergency contacts, in the order they were added.
final emergencyContactsProvider = StreamProvider<List<EmergencyContact>>((ref) {
  final uid = ref.watch(authStateProvider).profile?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(emergencyContactRepositoryProvider).watch(uid);
});

/// Ticks once a second, for invite countdowns.
final inviteClockProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
