import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The frame every auth screen sits in.
///
/// One gutter value, one back-button treatment, one scroll behaviour. The
/// screens differ in content, and this exists so they do not also differ in
/// their margins.
///
/// Scrolling is always on. An auth form on a small phone with the keyboard
/// up has less than 300 logical pixels of room; a screen that only scrolls
/// when someone remembered to wrap it is a screen that overflows on
/// somebody's device.
class NovaPage extends StatelessWidget {
  const NovaPage({
    super.key,
    required this.child,
    this.onBack,
    this.title,
    this.trailing,
    this.centred = false,
  });

  final Widget child;

  /// Shows a back arrow. Null means no arrow — a root screen.
  final VoidCallback? onBack;

  /// Sits beside the back arrow, not over the content.
  final String? title;
  final Widget? trailing;

  /// Centres the content vertically when it is shorter than the screen.
  /// For the short screens — splash, verify email — where a block floating
  /// at the top looks abandoned.
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onBack != null || title != null || trailing != null)
              _Header(onBack: onBack, title: title, trailing: trailing),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    AppSpacing.xxl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: centred ? constraints.maxHeight - AppSpacing.xxxl : 0,
                    ),
                    child: centred
                        ? Center(child: child)
                        : child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onBack, this.title, this.trailing});

  final VoidCallback? onBack;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.gutter,
        0,
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 22),
              color: colors.textSecondary,
              tooltip: 'Back',
            )
          else
            const SizedBox(width: AppSpacing.lg),
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: AppTypography.title.copyWith(color: colors.textPrimary),
              ),
            )
          else
            const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
