import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/nova_brand_mark.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../../../core/widgets/nova_inline_error.dart';
import '../../../../core/widgets/nova_page.dart';
import '../providers/auth_state.dart';

/// Where a signed-in but unverified account waits.
///
/// The router holds people here — it is not a screen anyone can navigate
/// past. Both actions are real now: "I have confirmed it" reloads the
/// Firebase user, and if the address has been confirmed the auth stream
/// fires and the gate moves on by itself. Signing out works too, because
/// otherwise this screen would be a trap for someone who mistyped their
/// address at sign-up.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, this.email});

  /// The address the link was sent to. Usually null — the signed-in
  /// profile is the better source and the build below prefers it.
  final String? email;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  bool _checking = false;
  bool _resending = false;
  String? _error;
  String? _notice;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _notice = null;
    });
    try {
      final profile = await ref.read(authRepositoryProvider).reloadUser();
      if (!mounted) return;
      setState(() {
        _checking = false;
        // When it worked, the auth stream has already moved the router
        // and this frame is on its way out. When it did not, the address
        // is still unconfirmed and saying so beats silence.
        _notice = profile.emailVerified
            ? null
            : 'Not confirmed yet. Open the link in the email, then try '
                'again.';
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _resending = false;
        _notice = 'Sent. Check your inbox, and the spam folder.';
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = _checking || _resending;
    final sentTo = widget.email ?? ref.watch(authStateProvider).profile?.email;

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
          const SizedBox(height: AppSpacing.xxl),
          NovaInlineError(message: _error),
          if (_notice != null) ...[
            Text(
              _notice!,
              textAlign: TextAlign.center,
              style: AppTypography.label.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          NovaPrimaryButton(
            label: 'I have confirmed it',
            busy: _checking,
            onPressed: busy ? null : _check,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: busy ? null : _resend,
            child: Text(_resending ? 'Sending…' : 'Send the link again'),
          ),
          const SizedBox(height: AppSpacing.xl),
          NovaTextAction(
            leading: 'Wrong address? ',
            label: 'Sign out',
            onPressed: busy
                ? null
                : () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
