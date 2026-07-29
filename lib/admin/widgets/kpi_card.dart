import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// One headline metric on the dashboard KPI row.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color accent;

  /// Tints the whole card — used when a metric needs attention (open alerts).
  final bool alarmed;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.accent = NovaColors.cyan,
    this.alarmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = alarmed ? NovaColors.red : accent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: alarmed ? NovaColors.red.withValues(alpha: 0.08) : NovaColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alarmed ? NovaColors.red.withValues(alpha: 0.5) : NovaColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              color: alarmed ? NovaColors.red : NovaColors.primaryText,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
