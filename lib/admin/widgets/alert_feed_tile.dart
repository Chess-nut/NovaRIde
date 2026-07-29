import 'package:flutter/material.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// One row in the emergency alert feed.
/// Crash and SOS tiles get a red-tinted background so they read first.
class AlertFeedTile extends StatelessWidget {
  final AlertEvent alert;

  const AlertFeedTile({super.key, required this.alert});

  static IconData iconFor(AlertType type) => switch (type) {
        AlertType.crash => Icons.car_crash,
        AlertType.alcoholWarning => Icons.local_bar,
        AlertType.lowBattery => Icons.battery_alert,
        AlertType.sos => Icons.sos,
      };

  static Color colorFor(AlertType type) => switch (type) {
        AlertType.crash => NovaColors.red,
        AlertType.alcoholWarning => NovaColors.amber,
        AlertType.lowBattery => NovaColors.cyan,
        AlertType.sos => NovaColors.red,
      };

  /// "3m ago" / "2h ago" — good enough for a mock feed.
  static String relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(alert.type);
    final critical = alert.type.isCritical;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: critical
            ? NovaColors.red.withValues(alpha: 0.10)
            : NovaColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: critical
              ? NovaColors.red.withValues(alpha: 0.45)
              : NovaColors.cardBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconFor(alert.type), color: color, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.type.label,
                  style: TextStyle(
                    color: critical ? NovaColors.red : NovaColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${alert.riderName} · ${alert.riderId}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill.alert(alert.status),
              const SizedBox(height: 5),
              Text(
                relativeTime(alert.timestamp),
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
