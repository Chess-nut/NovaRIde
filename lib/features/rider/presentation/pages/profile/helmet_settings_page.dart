import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/errors/firebase_failure_mapper.dart';
import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/theme/app_typography.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';

import '../../../domain/entities/helmet_telemetry.dart';
import '../../providers/helmet_telemetry_provider.dart';

/// "Helmet settings" — what the helmet is doing, and how to change what
/// it does.
///
/// The device card reads the same live node as Home. It used to show
/// 78% battery, -62 dBm and "NV-08567" under "Connected", none of which
/// came from anywhere.
///
/// **The app cannot write to the helmet.** Its real settings — Wi‑Fi,
/// the emergency number it texts, the alcohol threshold — are changed on
/// the helmet's own setup page, so this screen says how, step by step,
/// from the user manual. Detection is shown as it is (always on in this
/// firmware) with switches the rider cannot flip, rather than switches
/// that flip and change nothing. The Bluetooth "Auto-connect" toggle and
/// "Unpair helmet" button are gone: the helmet talks over Wi‑Fi, and
/// nothing pairs an account to a helmet yet.
class HelmetSettingsPage extends ConsumerWidget {
  const HelmetSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final deviceId = ref.watch(helmetDeviceIdProvider);
    final telemetryAsync = ref.watch(helmetTelemetryProvider);
    final now = ref.watch(helmetClockProvider).value ?? DateTime.now();

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const NovaScreenHeader(
              title: 'Helmet settings',
              subtitle: 'What your helmet is doing',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  kRiderGutter,
                  AppSpacing.lg,
                  kRiderGutter,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DeviceCard(
                      deviceId: deviceId,
                      telemetryAsync: telemetryAsync,
                      now: now,
                      onRetry: () => ref.invalidate(helmetTelemetryProvider),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Detection'),
                    const SizedBox(height: AppSpacing.md),
                    const NovaListGroup(
                      children: [
                        NovaSwitchRow(
                          icon: Icons.monitor_heart_outlined,
                          title: 'Crash detection',
                          subtitle: 'Accelerometer and tilt',
                          value: true,
                          onChanged: null,
                        ),
                        NovaSwitchRow(
                          icon: Icons.water_drop_outlined,
                          title: 'Alcohol detection',
                          subtitle: 'MQ‑3 breath sensor',
                          value: true,
                          onChanged: null,
                        ),
                        NovaSwitchRow(
                          icon: Icons.volume_up_outlined,
                          title: 'Alarm sound',
                          subtitle: 'Beeps on a warning',
                          value: true,
                          onChanged: null,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Always on in this version of the helmet. Turning them '
                      'off from the app is not supported yet.',
                      style: context.text.caption,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Change settings on the helmet'),
                    const SizedBox(height: AppSpacing.md),
                    const _SetupSteps(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The helmet's identity and live state.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.deviceId,
    required this.telemetryAsync,
    required this.now,
    required this.onRetry,
  });

  final String deviceId;
  final AsyncValue<HelmetTelemetry?> telemetryAsync;
  final DateTime now;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final failed = telemetryAsync.hasError && !telemetryAsync.isLoading;
    final t = failed ? null : telemetryAsync.value;
    final waiting = !failed && !telemetryAsync.hasValue;
    final live =
        t != null && t.online == true && t.isFresh(now, helmetStaleAfter);

    final (String pill, NovaTone tone) = failed
        ? ('Error', NovaTone.critical)
        : waiting
        ? ('Connecting…', NovaTone.offline)
        : t == null
        ? ('Never reported', NovaTone.offline)
        : live
        ? ('Live', NovaTone.safe)
        : ('Offline', NovaTone.offline);

    final lastSeen = t?.lastSeen;
    final ip = t?.ip;
    final connection = ip == null
        ? null
        : ip == 'cellular'
        ? 'Cellular'
        : 'Wi‑Fi · $ip';
    final fix = t?.hasUsableFix;
    final satellites = t?.satellites;

    return NovaCard(
      tone: failed ? NovaTone.critical : NovaTone.neutral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.sports_motorsports_outlined,
                size: 28,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NovaRide helmet', style: context.text.h2),
                    Text(deviceId, style: context.text.bodyMuted),
                  ],
                ),
              ),
              NovaPill(label: pill, tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (failed) ...[
            Text(messageFor(telemetryAsync.error!), style: context.text.body),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(onPressed: onRetry, child: const Text('Retry')),
            ),
          ] else ...[
            NovaValueRow(
              label: 'Last report',
              value: lastSeen == null ? '—' : novaTimeAgo(lastSeen, now),
            ),
            NovaValueRow(label: 'Connection', value: connection ?? '—'),
            NovaValueRow(
              label: 'Crash sensor',
              value: switch (t?.accelerometerReady) {
                true => 'Ready',
                false => 'Not ready',
                null => '—',
              },
            ),
            NovaValueRow(
              label: 'GPS',
              value: switch (fix) {
                true =>
                  satellites == null ? 'Fix' : 'Fix · $satellites satellites',
                false => 'No fix',
                null => '—',
              },
            ),
            // Said outright, so nobody goes looking for it.
            const NovaValueRow(label: 'Battery', value: 'Not measured'),
          ],
        ],
      ),
    );
  }
}

/// How to change the helmet's real settings, from the user manual.
class _SetupSteps extends StatelessWidget {
  const _SetupSteps();

  static const _steps = [
    (
      'Turn the helmet on',
      'Power the board, then press PWR on the AIR780E. Wait about a minute.',
    ),
    (
      'Join its Wi‑Fi',
      'Connect your phone to "SmartGPS-Setup" (password in the user '
          'manual). Turn mobile data off so the phone stays on it.',
    ),
    (
      'Open the setup page',
      'In a browser go to http://192.168.4.1 — http, not https.',
    ),
    (
      'Change what you need',
      'Home Wi‑Fi (2.4 GHz only), the emergency number it texts, and the '
          'alcohol threshold (about 1900). Tap Save after each.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return NovaCard(
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.border,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${i + 1}', style: context.text.label),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_steps[i].$1, style: context.text.title),
                      const SizedBox(height: 2),
                      Text(_steps[i].$2, style: context.text.bodyMuted),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
