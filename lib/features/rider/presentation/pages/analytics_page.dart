import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/shared/theme.dart';

import '../../domain/entities/rider_alert.dart';
import '../providers/rider_alerts_provider.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import '../widgets/nova_classic.dart';
import '../widgets/rider_alert_tile.dart';

/// "Analytics & History", in the original NovaRide look.
///
/// Everything shown comes from `alerts/`. The old page's impact chart,
/// safety score of 92 and "most frequent routes" were invented; they need
/// recorded rides, which NovaRide does not keep yet, so one card says so.
///
/// The counts are of the alerts the app loads, which the repository caps
/// at the newest 20 — so the card says "latest", not "all time".
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref.watch(linkedRiderProvider).value;
    final alertsAsync = ref.watch(riderAlertsProvider);
    final alerts = alertsAsync.value ?? const <RiderAlert>[];

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ClassicHeader(
                title: 'Analytics & History',
                subtitle: 'Your riding insights',
                showBack: false,
              ),
              const SizedBox(height: 24),
              if (alerts.isNotEmpty) ...[
                _Summary(alerts: alerts),
                const SizedBox(height: 24),
              ],
              const ClassicSectionTitle('Alert History'),
              const SizedBox(height: 14),
              if (alertsAsync.hasError)
                const ClassicNotice(
                  icon: Icons.error_outline,
                  color: NovaColors.red,
                  text:
                      'Couldn\'t load your alerts. They\'ll appear here once '
                      'the connection is back.',
                )
              else if (alerts.isEmpty)
                ClassicNotice(
                  icon: Icons.verified_user_outlined,
                  color: NovaColors.green,
                  title: 'No alerts recorded',
                  text: linked == null
                      ? 'Your history appears once operations links your '
                            'account to your helmet.'
                      : 'No crash, SOS or alcohol alert so far.',
                )
              else
                ClassicCard(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: [
                      for (var i = 0; i < alerts.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            color: NovaColors.cardBorder,
                          ),
                        ClassicAlertLine(alert: alerts[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const ClassicSectionTitle('Ride Insights'),
              const SizedBox(height: 14),
              const ClassicNotice(
                icon: Icons.insights_outlined,
                color: NovaColors.cyan,
                title: 'Needs recorded rides',
                text:
                    'Impact trends, a safety score and your usual routes will '
                    'appear once NovaRide records your rides. It doesn\'t yet.',
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
    int count(String type) => alerts.where((a) => a.type == type).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Count(
                value: count('crash'),
                label: 'CRASHES',
                color: NovaColors.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Count(
                value: count('sos'),
                label: 'SOS',
                color: NovaColors.pink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Count(
                value: count('alcoholWarning'),
                label: 'ALCOHOL',
                color: NovaColors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'From your latest ${alerts.length} '
          '${alerts.length == 1 ? 'alert' : 'alerts'}.',
          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, required this.color});

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClassicCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
