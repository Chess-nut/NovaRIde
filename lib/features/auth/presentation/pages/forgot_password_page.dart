import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../../../core/widgets/nova_page.dart';
import '../../../../core/widgets/nova_text_field.dart';

/// Ask for a password-reset link.
///
/// **No backend yet.** Phase 3 calls
/// `AuthRepository.sendPasswordResetEmail`, which completes normally for
/// an address that has no account — telling the caller which is which
/// would turn this screen into a way to find out who is registered. The
/// confirmation below already says "if that address has an account", so
/// the copy is right for the real thing and does not change in Phase 3.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NovaPage(
      onBack: context.canPop() ? context.pop : null,
      child: _sent ? _buildSent(context) : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = context.colors;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Reset your password',
            style: AppTypography.h1.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the email on your account and we will send you a link to '
            'choose a new password.',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          NovaTextField(
            label: 'Email',
            controller: _email,
            enabled: !_busy,
            autofocus: true,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          NovaPrimaryButton(
            label: 'Send reset link',
            busy: _busy,
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildSent(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        Icon(Icons.mark_email_read_outlined, size: 44, color: colors.action),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Check your email',
          style: AppTypography.h1.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        RichText(
          text: TextSpan(
            style: AppTypography.body.copyWith(color: colors.textSecondary),
            children: [
              // Says "if" on purpose: confirming that an address is
              // registered would make this screen an account-enumeration
              // oracle, and the wording has to survive into Phase 3.
              const TextSpan(text: 'If '),
              TextSpan(
                text: _email.text.trim(),
                style: TextStyle(color: colors.textPrimary),
              ),
              const TextSpan(
                text: ' has a NovaRide account, a reset link is on its way. '
                    'It expires in an hour.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        NovaPrimaryButton(
          label: 'Back to log in',
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        NovaTextAction(
          leading: 'Wrong address? ',
          label: 'Try another',
          onPressed: () => setState(() => _sent = false),
        ),
      ],
    );
  }
}
