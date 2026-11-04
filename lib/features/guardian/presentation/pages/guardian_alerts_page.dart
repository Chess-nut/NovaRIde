import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/nova_lists.dart';
import '../../../../core/widgets/nova_surfaces.dart';
import '../../../rider/domain/entities/rider_alert.dart';
import '../../../rider/presentation/widgets/rider_alert_tile.dart';
import '../providers/guardian_providers.dart';
import '../widgets/guardian_common.dart';

/// "Alerts" — what the rider's helmet has raised: anything still being
/// worked on top, past incidents below. History and alerts used to be two
/// tabs showing the same list; they are one now.
class GuardianAlertsPage extends ConsumerWidget {
  const GuardianAlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final link = ref.watch(myGuardianLinkProvider).value;
    final account = ref.watch(followedRiderAccountProvider).value;
    final rosterAsync = ref.watch(followedRosterProvider);
    final alertsAsync = ref.watch(followedAlertsProvider);
    final alerts = alertsAsync.value ?? const <RiderAlert>[];
    final name = account?.firstName;

    final live = alerts.where((a) => a.isLive).toList();
    final past = alerts.where((a) => !a.isLive).toList();

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NovaScreenHeader(
              title: 'Alerts',
              subtitle: name == null
                  ? 'What the helmet has raised'
                  : 'Everything $name\'s helmet has raised',
              showBack: false,
            ),
            Expanded(
              child: link == null
                  ? const GuardianNotLinked()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(kRiderGutter,
                          AppSpacing.lg, kRiderGutter, AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (alertsAsync.hasError)
                            const NovaNote(
                              tone: NovaTone.critical,
                              icon: Icons.error_outline,
                              text: 'Couldn\'t load alerts. They\'ll appear '
                                  'here once the connection is back.',
                            )
                          else if (rosterAsync.hasValue &&
                              rosterAsync.value == null)
                            NovaEmptyState(
                              icon: Icons.link_off,
                              title: 'No helmet linked yet',
                              message: 'Alerts appear once operations links '
                                  '${name ?? 'the rider'}\'s account to a '
                                  'helmet.',
                            )
                          else if (alerts.isEmpty)
                            const NovaEmptyState(
                              icon: Icons.verified_user_outlined,
                              title: 'No alerts',
                              message: 'Nothing has happened. Alerts the '
                                  'helmet raises appear here.',
                            )
                          else ...[
                            const NovaSectionLabel('Happening now'),
                            const SizedBox(height: AppSpacing.md),
                            if (live.isEmpty)
                              Text('Nothing right now.',
                                  style: context.text.bodyMuted)
                            else
                              for (final alert in live) ...[
                                _LiveAlertCard(alert: alert),
                                const SizedBox(height: AppSpacing.md),
                              ],
                            const SizedBox(height: AppSpacing.xxl),
                            const NovaSectionLabel('Past incidents'),
                            const SizedBox(height: AppSpacing.md),
                            if (past.isEmpty)
                              Text('None yet.', style: context.text.bodyMuted)
                            else
                              NovaListGroup(children: [
                                for (final alert in past)
                                  RiderAlertRow(alert: alert),
                              ]),
                            if (alerts.length >= 20) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text('Showing the latest 20.',
                                  style: context.text.caption),
                            ],
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const GuardianBottomNavBar(selectedIndex: 2),
    );
  }
}

class _LiveAlertCard extends StatelessWidget {
  const _LiveAlertCard({required this.alert});

  final RiderAlert alert;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, icon) = alertTypeLabel(alert.type);
    final (status, tone) = alertStatusLabel(alert);
    final when = alert.timestamp;
    final critical = alert.isCritical;

    return NovaCard(
      tone: critical ? NovaTone.critical : NovaTone.warning,
      semanticLabel: '$label, $status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: critical ? colors.critical : colors.warning, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(label, style: context.text.title)),
              NovaPill(label: status, tone: tone),
            ],
          ),
          if (when != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(novaTimeAgo(when), style: context.text.bodyMuted),
          ],
        ],
      ),
    );
  }
}
