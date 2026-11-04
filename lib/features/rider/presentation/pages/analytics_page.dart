import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/theme/app_typography.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';

import '../../domain/entities/rider_alert.dart';
import '../providers/rider_alerts_provider.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import '../widgets/rider_alert_tile.dart';

/// "Analytics" — what the helmet has recorded about this rider.
///
/// Everything here now comes from `alerts/`. It used to show a week of
/// impact readings, three May 2026 alerts on EDSA and Makati Avenue, a
/// safety score of 92 "+5 this week" and two "frequent routes" — none of
/// it recorded anywhere.
///
/// The counts are of the alerts the app loads, which the repository caps
/// at the newest 20 — so the card says "latest", not "all time".
///
/// Impact trends, a score and routes need rides to be recorded, and they
/// are not; one card says so instead of three charts pretending.
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final linked = ref.watch(linkedRiderProvider).value;
    final alertsAsync = ref.watch(riderAlertsProvider);
    final alerts = alertsAsync.value ?? const <RiderAlert>[];

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NovaScreenHeader(
                title: 'Analytics',
                subtitle: 'What your helmet has recorded',
                showBack: false,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kRiderGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    if (alerts.isNotEmpty) ...[
                      _Summary(alerts: alerts),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                    const NovaSectionLabel('Alert history'),
                    const SizedBox(height: AppSpacing.md),
                    if (alertsAsync.hasError)
                      const NovaNote(
                        tone: NovaTone.critical,
                        icon: Icons.error_outline,
                        text:
                            'Couldn\'t load your alerts. They\'ll appear here '
                            'once the connection is back.',
                      )
                    else if (alerts.isEmpty)
                      NovaEmptyState(
                        icon: Icons.verified_user_outlined,
                        title: 'No alerts recorded',
                        message: linked == null
                            ? 'Your history appears once operations links your '
                                  'account to your helmet.'
                            : 'No crash, SOS or alcohol alert so far.',
                      )
                    else
                      NovaListGroup(
                        children: [
                          for (final alert in alerts)
                            RiderAlertRow(alert: alert),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Ride insights'),
                    const SizedBox(height: AppSpacing.md),
                    const NovaEmptyState(
                      icon: Icons.insights_outlined,
                      title: 'Needs recorded rides',
                      message:
                          'Impact trends, a safety score and your usual '
                          'routes will appear once NovaRide records your '
                          'rides. It doesn\'t yet.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 1),
    );
  }
}

/// Counts by kind, from the alerts loaded.
class _Summary extends StatelessWidget {
  const _Summary({required this.alerts});

  final List<RiderAlert> alerts;

  @override
  Widget build(BuildContext context) {
    int count(bool Function(RiderAlert) test) => alerts.where(test).length;

    final crashes = count((a) => a.type == 'crash');
    final sos = count((a) => a.type == 'sos');
    final alcohol = count((a) => a.type == 'alcoholWarning');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Count(value: crashes, label: 'Crashes'),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _Count(value: sos, label: 'SOS'),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _Count(value: alcohol, label: 'Alcohol'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'From your latest ${alerts.length} '
          '${alerts.length == 1 ? 'alert' : 'alerts'}.',
          style: context.text.caption,
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: context.text.h1),
          const SizedBox(height: 2),
          Text(label, style: context.text.labelMuted),
        ],
      ),
    );
  }
}
