import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/nova_brand_mark.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../../../core/widgets/nova_page.dart';
import '../providers/auth_state.dart';

/// Where a signed-in but unverified account waits.
///
/// The router holds people here — it is not a screen anyone can navigate
/// past, which is the point of it existing before real auth does.
///
/// Two of the three actions are disabled until Phase 3: "I have confirmed
/// it" needs `AuthRepository.reloadUser` and "Send the link again" needs
/// `sendEmailVerification`. They are shown disabled rather than hidden so
/// the screen is honest about what it will do, and so the layout does not
/// change when they start working. Signing out works today, because
/// otherwise this screen would be a trap: someone who mistyped their
/// address at sign-up could not get back out of it.
class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key, this.email});

  /// The address the link was sent to. Null until real auth supplies it.
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sentTo = email ?? ref.watch(authStateProvider).profile?.email;

    return NovaPage(
      centred: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: NovaLogoMark(size: 72)),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Confirm your email',
            textAlign: TextAlign.center,
            style: AppTypography.h1.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            sentTo == null
                ? 'We have sent you a confirmation link. Open it, then come '
                    'back here.'
                : 'We have sent a confirmation link to $sentTo. Open it, '
                    'then come back here.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          const NovaPrimaryButton(
            label: 'I have confirmed it',
            onPressed: null,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: null,
            child: const Text('Send the link again'),
          ),
          const SizedBox(height: AppSpacing.xl),
          NovaTextAction(
            leading: 'Wrong address? ',
            label: 'Sign out',
            onPressed: () => ref.read(authStateProvider.notifier).signedOut(),
          ),
        ],
      ),
    );
  }
}
