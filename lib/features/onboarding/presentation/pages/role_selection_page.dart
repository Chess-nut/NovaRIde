import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/nova_page.dart';
import '../../../auth/domain/entities/user_role.dart';

/// "Select User Type" — the one screen where choosing a role *is* the
/// task, so the two options get the full-card treatment the login screen's
/// toggle deliberately does not.
///
/// The cards carry a status colour each, matching the vocabulary the rest
/// of the app uses: the rider is the one being kept safe, the guardian is
/// the one watching.
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return NovaPage(
      onBack: context.canPop() ? context.pop : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Who is using NovaRide?',
            style: AppTypography.h1.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This decides what you see when you sign in. You can only be '
            'one on an account.',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          _RoleCard(
            icon: Icons.sports_motorsports_outlined,
            tint: colors.safe,
            title: 'Motorcycle Rider',
            detail: 'You wear the helmet. NovaRide watches your ride and '
                'raises the alarm if something happens.',
            onTap: () => context.push(
              '${AppRoutes.loginPath}?role=${UserRole.rider.wireName}',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _RoleCard(
            icon: Icons.favorite_outline,
            tint: colors.riding,
            title: 'Family / Emergency Contact',
            detail: 'You follow a rider from home and are the first to know '
                'if they need help.',
            onTap: () => context.push(
              '${AppRoutes.loginPath}?role=${UserRole.guardian.wireName}',
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: tint, size: 24),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.title
                          .copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      detail,
                      style: AppTypography.caption
                          .copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.arrow_forward,
                color: colors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
