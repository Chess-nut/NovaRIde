import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The one saturated control on a screen.
///
/// Carries its own [busy] state because every auth action is a network
/// call, and a button that stays pressable during one invites a double
/// sign-up. Busy disables the button and swaps the label for a spinner at
/// the same size, so the layout does not move.
class NovaPrimaryButton extends StatelessWidget {
  const NovaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;

  /// Null disables the button, as it does on any Flutter button.
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      height: AppSizes.buttonHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onAction,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// A quiet action that sits under the primary one — "Forgot password?",
/// "Create an account". Rendered as text with the accent reserved for the
/// word that is actually tappable.
class NovaTextAction extends StatelessWidget {
  const NovaTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
  });

  /// The tappable words.
  final String label;
  final VoidCallback? onPressed;

  /// Untappable copy in front of it — "Already have an account? ".
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null)
          // Flexible, because the leading copy is the longest string on
          // some of these screens and a phone at 320pt has 264pt of
          // usable width. It wraps rather than overflowing.
          Flexible(
            child: Text(
              leading!,
              style: AppTypography.label.copyWith(color: colors.textSecondary),
            ),
          ),
        // A tap target of its own, so the words are not a 13px hit area.
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.md,
            ),
            child: Text(
              label,
              style: AppTypography.label.copyWith(
                color: colors.action,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
