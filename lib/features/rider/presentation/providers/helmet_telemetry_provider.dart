/// The helmet's live telemetry, for the rider home screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../domain/entities/helmet_telemetry.dart';

/// Which helmet to watch.
///
/// TODO(account-helmet-link): resolve this from the signed-in account
/// instead. `riders/{R-xxx}.authUid` would link the account to its roster
/// entry, and that entry's `helmetId` names the helmet; nothing writes
/// `authUid` yet. Until then every rider sees the one helmet named by
/// `--dart-define=HELMET_DEVICE_ID=...`.
final helmetDeviceIdProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'HELMET_DEVICE_ID',
    defaultValue: 'tracker-001',
  );
});

/// How long after its last write a helmet still counts as connected.
///
/// The firmware rewrites `deviceStatus` every 30 s over Wi-Fi and every
/// 60 s over cellular, and a cellular write may take up to 90 s
/// (`CELLULAR_HTTP_TIMEOUT_MS`) before it lands. So on cellular the honest
/// gap between two writes is up to ~150 s. Three minutes covers that with
/// room for the phone's clock being a little off the server's. The cost:
/// a helmet that dies shows as connected for up to three minutes after
/// its last write.
const helmetStaleAfter = Duration(minutes: 3);

/// The helmet's telemetry for [helmetDeviceIdProvider]. Null data means
/// there is nothing at that id.
///
/// No automatic retry. A Realtime Database listener does not fail when
/// the network drops — it waits — so the errors that do arrive are the
/// rules refusing the read, which retrying cannot fix. Riverpod's default
/// would hide one behind "Connecting…" for ~40 s; the screen shows it at
/// once instead, with a Retry button.
final helmetTelemetryProvider = StreamProvider<HelmetTelemetry?>(
  (ref) {
    final deviceId = ref.watch(helmetDeviceIdProvider);
    return ref.watch(helmetTelemetryRepositoryProvider).watch(deviceId);
  },
  retry: (_, _) => null,
);

/// Ticks so freshness is re-judged when the helmet stops writing — a
/// silent helmet produces no event to trigger a rebuild on its own.
final helmetClockProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 5), (_) => DateTime.now());
});
