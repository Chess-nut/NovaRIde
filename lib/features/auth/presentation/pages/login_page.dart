import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/nova_brand_mark.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../../../core/widgets/nova_inline_error.dart';
import '../../../../core/widgets/nova_page.dart';
import '../../../../core/widgets/nova_role_toggle.dart';
import '../../../../core/widgets/nova_text_field.dart';
import '../../domain/entities/user_role.dart';
import '../../../../app/di.dart';
import '../../../../core/errors/failure.dart';

/// Sign in.
///
/// Signs in with Firebase Auth through [AuthRepository] using an email
/// address. Username login is disabled until a private server-side lookup
/// can replace the old public username-to-email mapping.
///
/// It does not navigate. It signs in, the repository's auth stream
/// updates [authStateProvider], and the router's gate decides where that
/// goes — the role's home, or the verify-email screen when the address
/// has not been confirmed. That indirection is what lets the gate be the
/// only place in the app that knows the rules for who sees what.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.role = UserRole.rider});

  /// Which role to use when creating a first-time Google profile. Existing
  /// accounts always use the role already stored in Firestore.
  final UserRole role;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  late UserRole _role = widget.role;
  bool _busy = false;
  String? _formError;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _formError = null;
    });

    final identifier = _identifier.text.trim();
    try {
      final repository = ref.read(authRepositoryProvider);
      final profile = await repository.signInWithEmail(
        email: identifier,
        password: _password.text,
        role: _role,
      );

      AppLogger.i(
        'Signed in as ${profile.username} '
        '(${profile.role.wireName}).',
      );
      // No navigation here. The repository's auth stream updates
      // authStateProvider and the router's gate moves to the role's home
      // — or to verify-email if the address is not confirmed yet.
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = failure.message;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _formError = null;
    });

    try {
      final profile = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle(role: _role);
      AppLogger.i('Signed in with Google as ${profile.role.wireName}.');
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _formError = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isRider = _role == UserRole.rider;

    return NovaPage(
      onBack: context.canPop() ? context.pop : null,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const NovaWordmark(fontSize: 20, textAlign: TextAlign.left),
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                'Welcome back',
                style: AppTypography.h1.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isRider
                    ? 'Sign in to start a ride with NovaRide watching.'
                    : 'Sign in to keep an eye on your rider.',
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              NovaRoleToggle(
                value: _role,
                onChanged: _busy
                    ? null
                    : (role) => setState(() => _role = role),
              ),
              const SizedBox(height: AppSpacing.xxl),
              NovaTextField(
                label: 'Email address',
                controller: _identifier,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.xl),
              NovaTextField(
                label: 'Password',
                controller: _password,
                enabled: !_busy,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                // Sign-in checks only that something was typed. Applying
                // the sign-up rules here would refuse an older account's
                // valid password and lock someone out.
                validator: Validators.passwordPresent,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.push(AppRoutes.forgotPasswordPath),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              NovaInlineError(message: _formError),
              NovaPrimaryButton(
                label: 'Log in',
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _busy ? null : _signInWithGoogle,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.border),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              NovaTextAction(
                leading: "Don't have an account? ",
                label: 'Sign up',
                onPressed: _busy
                    ? null
                    : () => context.push(
                        '${AppRoutes.signupPath}?role=${_role.wireName}',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
