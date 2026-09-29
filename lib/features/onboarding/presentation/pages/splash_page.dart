import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/nova_brand_mark.dart';

/// What is on screen while the router works out where to send you.
///
/// No logic and no timer. The router's redirect moves off it the moment
/// the session resolves; if the app is sitting here, the session is
/// genuinely still unknown.
///
/// The spinner is deliberately small and low — a full-width progress bar
/// would make a 200ms wait look like a problem.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NovaLogoMark(size: 72),
            const SizedBox(height: AppSpacing.xxl),
            const NovaWordmark(fontSize: 26),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
