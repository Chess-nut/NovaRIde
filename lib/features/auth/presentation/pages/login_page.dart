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
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_role.dart';
import '../providers/auth_state.dart';

/// Sign in.
///
/// **Still the hardcoded demo credential** — `admin` / `admin123`. Phase 3
/// replaces `_attemptSignIn` with a call to `AuthRepository`; everything
/// else on this screen is finished.
///
/// One thing did change in how it signs in. It no longer pushes the home
/// screen itself: it sets the session on [authStateProvider], and the
/// router's gate does the navigating. That is the path real auth will
/// take, so Phase 3 swaps where the profile comes from and nothing about
/// the navigation moves.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.role = UserRole.rider});

  /// Which copy to show and, until real auth knows better, which home to
  /// land on. An existing account's real role comes from Firestore in
  /// Phase 3 and this becomes a presentation detail only.
  final UserRole role;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _demoUsername = 'admin';
  static const _demoPassword = 'admin123';

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

    final profile = await _attemptSignIn(
      identifier: _identifier.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;

    if (profile == null) {
      setState(() {
        _busy = false;
        // One sentence for a wrong password and an unknown account, the
        // same rule core/errors/firebase_failure_mapper.dart keeps: a
        // message that tells them apart says which accounts exist.
        _formError = 'Incorrect username or password.';
      });
      return;
    }

    AppLogger.i('Signed in as ${profile.username} (${profile.role.wireName}).');
    // No navigation here on purpose — see the class comment.
    ref.read(authStateProvider.notifier).signedIn(profile);
  }

  /// Phase 3 replaces the body of this method and nothing above it.
  Future<UserProfile?> _attemptSignIn({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (identifier != _demoUsername || password != _demoPassword) return null;
    return UserProfile(
      uid: 'demo-${_role.wireName}',
      email: 'demo@novaride.test',
      username: identifier,
      fullName: 'Demo Account',
      role: _role,
      emailVerified: true,
    );
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
                style:
                    AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              NovaRoleToggle(
                value: _role,
                onChanged:
                    _busy ? null : (role) => setState(() => _role = role),
              ),
              const SizedBox(height: AppSpacing.xxl),
              NovaTextField(
                label: 'Email or username',
                controller: _identifier,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: Validators.emailOrUsername,
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
