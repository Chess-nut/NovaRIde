import 'package:flutter/material.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Newest-first alert ticker. The type is the headline — an operator scanning
/// this column should register "CRASH DETECTED" before anything else.
class RecentAlertsFeedPanel extends StatelessWidget {
  final List<AlertEvent> alerts;

  const RecentAlertsFeedPanel({super.key, required this.alerts});

  static Color colorFor(AlertType type) => switch (type) {
        AlertType.crash => NovaColors.red,
        AlertType.sos => NovaColors.red,
        AlertType.alcoholWarning => NovaColors.amber,
        AlertType.lowBattery => NovaColors.cyan,
      };

  /// "7/30/2026, 2:28 PM" — hand-rolled; intl would be a dependency for one line.
  static String formatStamp(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final meridiem = t.hour < 12 ? 'AM' : 'PM';
    return '${t.month}/${t.day}/${t.year}, $hour12:$minute $meridiem';
  }

  @override
  Widget build(BuildContext context) {
    return DashPanel(
      title: 'Recent alert',
      contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: alerts.isEmpty
          ? const Center(
              child: Text(
                'No alerts on the board',
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 11,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 4),
              itemCount: alerts.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: NovaColors.cardBorder),
              itemBuilder: (context, index) => _FeedEntry(
                // Keyed by id so only a genuinely new alert plays the entry
                // animation — the rest just shuffle down.
                key: ValueKey(alerts[index].id),
                alert: alerts[index],
                animateIn: index == 0,
              ),
            ),
    );
  }
}

class _FeedEntry extends StatelessWidget {
  final AlertEvent alert;
  final bool animateIn;

  const _FeedEntry({super.key, required this.alert, required this.animateIn});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  alert.type.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: RecentAlertsFeedPanel.colorFor(alert.type),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  RecentAlertsFeedPanel.formatStamp(alert.timestamp),
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${alert.riderName} · ${alert.address}',
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    if (!animateIn) return row;

    return TweenAnimationBuilder<double>(
      key: ValueKey('in-${alert.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, -14 * (1 - t)), child: child),
      ),
      child: row,
    );
  }
}
