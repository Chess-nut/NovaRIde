import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Rider / Family, as a quiet segmented control.
///
/// Deliberately understated. Most people choose once and never touch it
/// again, so it does not deserve the weight of two large cards on a screen
/// whose job is to get someone signed in — that treatment belongs on
/// Select User Type, where choosing *is* the task.
///
/// The labels are shortened from [UserRole.label]: "Family / Emergency
/// Contact" does not fit a segment, and next to "Rider" the word "Family"
/// is unambiguous.
class NovaRoleToggle extends StatelessWidget {
  const NovaRoleToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UserRole value;
  final ValueChanged<UserRole>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _Segment(
            label: 'Rider',
            selected: value == UserRole.rider,
            onTap: onChanged == null ? null : () => onChanged!(UserRole.rider),
          ),
          _Segment(
            label: 'Family',
            selected: value == UserRole.guardian,
            onTap:
                onChanged == null ? null : () => onChanged!(UserRole.guardian),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // The selected segment is a raised surface, not the action
              // colour: green here would compete with the button below,
              // and only one thing per screen gets to be green.
              color: selected ? colors.surfaceRaised : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              style: AppTypography.label.copyWith(
                color: selected ? colors.textPrimary : colors.textMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
