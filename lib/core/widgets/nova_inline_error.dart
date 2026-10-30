import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A failure that belongs to the form as a whole rather than to one field
/// — "Incorrect email or password", "No connection to NovaRide".
///
/// Inline and above the button, not a SnackBar. A SnackBar covers the
/// thing it is complaining about, times out while someone is still
/// reading, and is gone by the time they look back. This stays until the
/// next attempt.
///
/// Takes a [Failure]'s message, which
/// `core/errors/firebase_failure_mapper.dart` has already made into a
/// sentence. Nothing here ever receives an exception.
class NovaInlineError extends StatelessWidget {
  const NovaInlineError({super.key, required this.message});

  /// Null renders nothing at all — no reserved gap, so the form does not
  /// carry a hole waiting for an error that may never come.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();

    final colors = context.colors;

    // The status colour is a left edge rather than a fill: a red panel
    // reads as a crash, and a wrong password is not one.
    //
    // Built as a clipped row rather than a Border with one thick side —
    // Flutter cannot paint a non-uniform border on a rounded box, and
    // asking it to throws during paint rather than at build, which makes
    // it a crash nobody sees until the error state is actually reached.
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: colors.critical),
              Expanded(
                child: Container(
                  color: colors.surfaceRaised,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          size: 18, color: colors.critical),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          text,
                          style: AppTypography.label
                              .copyWith(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
