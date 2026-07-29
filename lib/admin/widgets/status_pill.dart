import 'package:flutter/material.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Small rounded chip used for rider status and alert status.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  /// Pill for a rider's live status.
  factory StatusPill.rider(RiderStatus status) {
    return StatusPill(label: status.label, color: colorForRider(status));
  }

  /// Pill for where an alert sits in the dispatch workflow.
  factory StatusPill.alert(AlertStatus status) {
    return StatusPill(label: status.label, color: colorForAlert(status));
  }

  static Color colorForRider(RiderStatus status) => switch (status) {
        RiderStatus.riding => NovaColors.green,
        RiderStatus.idle => NovaColors.cyan,
        RiderStatus.offline => NovaColors.secondaryText,
        RiderStatus.emergency => NovaColors.red,
      };

  static Color colorForAlert(AlertStatus status) => switch (status) {
        AlertStatus.open => NovaColors.red,
        AlertStatus.acknowledged => NovaColors.cyan,
        AlertStatus.dispatched => NovaColors.pink,
        AlertStatus.resolved => NovaColors.green,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 6),
          // Flexible so a narrow table column shrinks the pill instead of
          // overflowing it.
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
