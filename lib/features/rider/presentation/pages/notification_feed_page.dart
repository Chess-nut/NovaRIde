import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/shared/theme.dart';

import '../../domain/entities/rider_alert.dart';
import '../providers/rider_alerts_provider.dart';
import '../widgets/nova_classic.dart';
import '../widgets/rider_alert_tile.dart';
import 'profile/notifications_page.dart';

/// "Notifications" — opened from the bell on Home, in the original look.
///
/// Built from this rider's real alerts (`alerts/`), newest first, grouped
/// TODAY and EARLIER. The old feed's eight messages were invented, and so
/// was its unread count: nothing stores what has been read, so there is
/// no "Mark all read". The tune icon still opens notification settings.
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

    final groups = <String, List<RiderAlert>>{
      'TODAY': alerts.where(isToday).toList(),
      'EARLIER': alerts.where((a) => !isToday(a)).toList(),
    };

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: ClassicHeader(
                title: 'Notifications',
                subtitle: 'Alerts from your helmet',
                trailing: IconButton(
                  tooltip: 'Notification settings',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsPage(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.tune,
                    color: NovaColors.secondaryText,
                    size: 22,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (alertsAsync.hasError)
                      const ClassicNotice(
                        icon: Icons.error_outline,
                        color: NovaColors.red,
                        text:
                            'Couldn\'t load your notifications. They\'ll '
                            'appear here once the connection is back.',
                      )
                    else if (alerts.isEmpty)
                      ClassicNotice(
                        icon: Icons.notifications_none,
                        color: NovaColors.cyan,
                        title: 'No notifications',
                        text: linked == null
                            ? 'They appear once operations links your account '
                                  'to your helmet.'
                            : 'You\'re all caught up.',
                      )
                    else
                      for (final entry in groups.entries)
                        if (entry.value.isNotEmpty) ...[
                          ClassicCapsLabel(entry.key),
                          const SizedBox(height: 10),
                          for (final a in entry.value)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ClassicAlertCard(alert: a),
                            ),
                          const SizedBox(height: 14),
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
