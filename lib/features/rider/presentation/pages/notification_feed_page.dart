import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';

import '../../domain/entities/rider_alert.dart';
import '../providers/rider_alerts_provider.dart';
import '../widgets/rider_alert_tile.dart';

/// "Notifications" — opened from the bell on Home.
///
/// Built from this rider's real alerts (`alerts/`), newest first, in two
/// groups: today and earlier. It used to be eight invented messages — a
/// safety score of 92, a battery at 15%, a crash on EDSA, firmware v4.2,
/// helmet NV-08567 — with read/unread state that reset on every visit.
/// "Mark all read" is gone with them: nothing stores what has been read.
class NotificationFeedPage extends ConsumerWidget {
  const NotificationFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref.watch(linkedRiderProvider).value;
    final alertsAsync = ref.watch(riderAlertsProvider);
    final alerts = alertsAsync.value ?? const <RiderAlert>[];

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    bool isToday(RiderAlert a) {
      final t = a.timestamp?.toLocal();
      return t != null && !t.isBefore(startOfToday);
    }

    final today = alerts.where(isToday).toList();
    final earlier = alerts.where((a) => !isToday(a)).toList();

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const NovaScreenHeader(
              title: 'Notifications',
              subtitle: 'Alerts from your helmet',
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
                    if (alertsAsync.hasError)
                      const NovaNote(
                        tone: NovaTone.critical,
                        icon: Icons.error_outline,
                        text:
                            'Couldn\'t load your notifications. They\'ll '
                            'appear here once the connection is back.',
                      )
                    else if (alerts.isEmpty)
                      NovaEmptyState(
                        icon: Icons.notifications_none,
                        title: 'No notifications',
                        message: linked == null
                            ? 'They appear once operations links your account '
                                  'to your helmet.'
                            : 'You\'re all caught up.',
                      )
                    else ...[
                      if (today.isNotEmpty) ...[
                        const NovaSectionLabel('Today'),
                        const SizedBox(height: AppSpacing.md),
                        NovaListGroup(
                          children: [
                            for (final a in today) RiderAlertRow(alert: a),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                      if (earlier.isNotEmpty) ...[
                        const NovaSectionLabel('Earlier'),
                        const SizedBox(height: AppSpacing.md),
                        NovaListGroup(
                          children: [
                            for (final a in earlier) RiderAlertRow(alert: a),
                          ],
                        ),
                      ],
                    ],
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
