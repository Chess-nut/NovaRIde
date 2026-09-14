import 'package:flutter/material.dart';
import 'package:novaride/family/models/family_models.dart';
import 'package:novaride/shared/theme.dart';

class FamilyStatusBadge extends StatelessWidget {
  final FamilyRiderStatus status;
  final bool isCompact;

  const FamilyStatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 5 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: isCompact ? 7 : 8),
          SizedBox(width: isCompact ? 4 : 5),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: isCompact ? 9 : 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class FamilySectionTitle extends StatelessWidget {
  final String label;
  final bool showLiveBadge;

  const FamilySectionTitle({
    super.key,
    required this.label,
    this.showLiveBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        if (showLiveBadge) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: NovaColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: NovaColors.green,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
