import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/nova_brand_mark.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../../../core/widgets/nova_page.dart';

/// The first thing anyone sees.
///
/// Signal's version of this screen is mostly space. The old one gave three
/// coloured pills equal visual weight with the button, which meant the eye
/// had four places to land on a screen with one job. Now the pills are
/// quiet rows — the colour on each is doing real work, because crash
/// detection, SOS and tracking map onto the same status colours the
/// guardian dashboards use, so the vocabulary is being taught here — and
/// the only saturated thing is "Get started".
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Centred and scrollable rather than a Column of Spacers. The old
    // version distributed the content with flex, which looks right until
    // a 320x568 phone, where the same content is 80 pixels taller than
    // the screen and Spacers have nothing left to give — an overflow, not
    // a squeeze. Centring holds the composition on a normal phone and
    // scrolls on a small one.
    return NovaPage(
      centred: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Center(child: NovaLogoMark(size: 96)),
          const SizedBox(height: AppSpacing.xxl),
          const Center(child: NovaWordmark(fontSize: 34)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Every second counts after a crash.\n'
            'NovaRide makes sure help never waits.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          const _CapabilityList(),
          const SizedBox(height: AppSpacing.xxxl),
          NovaPrimaryButton(
            label: 'Get started',
            onPressed: () => context.push(AppRoutes.selectUserTypePath),
          ),
          const SizedBox(height: AppSpacing.sm),
          NovaTextAction(
            leading: 'Already have an account? ',
            label: 'Log in',
            onPressed: () => context.push(AppRoutes.loginPath),
          ),
        ],
      ),
    );
  }
}

/// The three things the helmet does.
///
/// A list rather than a row of pills: at 28px gutters on a small phone the
/// pills had to wrap their labels onto two lines, and three two-line
/// labels side by side is harder to read than three sentences stacked.
class _CapabilityList extends StatelessWidget {
  const _CapabilityList();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        _Capability(
          icon: Icons.sensors,
          tint: colors.critical,
          title: 'Crash detection',
          detail: 'Two sensors have to agree before an alert goes out.',
        ),
        const SizedBox(height: AppSpacing.xl),
        _Capability(
          icon: Icons.sos_rounded,
          tint: colors.sos,
          title: 'Instant SOS',
          detail: 'Reach your emergency contacts without taking a hand off.',
        ),
        const SizedBox(height: AppSpacing.xl),
        _Capability(
          icon: Icons.location_on_outlined,
          tint: colors.safe,
          title: 'Live tracking',
          detail: 'Family can see where you are while you ride.',
        ),
      ],
    );
  }
}

class _Capability extends StatelessWidget {
  const _Capability({
    required this.icon,
    required this.tint,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: tint, size: 20),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    AppTypography.title.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style:
                    AppTypography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
