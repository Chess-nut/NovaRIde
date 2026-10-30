import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../core/errors/failure.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../../../core/widgets/nova_inline_error.dart';
import '../../../../core/widgets/nova_page.dart';
import '../../../../core/widgets/nova_text_field.dart';
import '../../domain/entities/user_role.dart';
import 'legal_document_page.dart';

/// Create an account.
///
/// Creates the Firebase account, claims the username and writes profile
/// documents through [AuthRepository].
///
/// The consent copy is the part to leave alone without asking. It names
/// GPS sharing with emergency contacts and the operator during an SOS,
/// which is the disclosure the study's ethics approval rests on.
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key, this.role = UserRole.rider});

  final UserRole role;

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _busy = false;
  bool _agreedToTerms = false;
  bool _showConsentError = false;

  /// A failure that belongs to the form rather than to one field.
  String? _formError;

  /// A username the server refused. Shown on the field until the text
  /// changes, because "taken" is only true of the value that was tried.
  String? _usernameError;

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState!.validate();

    // Consent is checked alongside the fields, not instead of them: a
    // person who has both an invalid email and no tick should see both,
    // rather than fix one and discover the other.
    setState(() => _showConsentError = !_agreedToTerms);
    if (!formValid || !_agreedToTerms) return;

    setState(() {
      _busy = true;
      _formError = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            email: _email.text.trim(),
            password: _password.text,
            username: _username.text.trim(),
            fullName: _fullName.text.trim(),
            role: widget.role,
            phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      // No navigation and no snackbar. signUp leaves the account signed
      // in and unverified, its auth stream updates authStateProvider, and
      // the router's gate lands on the verify-email screen — which is
      // where someone who just signed up should be.
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // A taken username comes back as a ValidationFailure naming the
        // field. Put it on the field rather than in the banner, so the
        // thing to fix is where the eye already is.
        if (failure is ValidationFailure && failure.field == 'username') {
          _usernameError = failure.message;
          _formKey.currentState?.validate();
        } else {
          _formError = failure.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isRider = widget.role == UserRole.rider;

    return NovaPage(
      onBack: context.canPop() ? context.pop : null,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                isRider ? 'Create a rider account' : 'Create a family account',
                style: AppTypography.h1.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isRider
                    ? 'This is the account your helmet reports to.'
                    : 'You will connect to your rider once you are signed in.',
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              NovaTextField(
                label: 'Full name',
                controller: _fullName,
                enabled: !_busy,
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.name],
                validator: Validators.fullName,
              ),
              const SizedBox(height: AppSpacing.xl),
              NovaTextField(
                label: 'Username',
                controller: _username,
                enabled: !_busy,
                helper: 'How you will log in. 3 to 20 characters.',
                maxLength: 20,
                autofillHints: const [AutofillHints.newUsername],
                validator: (value) =>
                    _usernameError ?? Validators.username(value),
                onChanged: (_) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              NovaTextField(
                label: 'Email',
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.xl),
              NovaTextField(
                label: 'Mobile number',
                controller: _phone,
                enabled: !_busy,
                hint: '09171234567',
                helper: 'Optional. Used to reach you during an emergency.',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: Validators.phoneNumber,
              ),
              const SizedBox(height: AppSpacing.xl),
              NovaTextField(
                label: 'Password',
                controller: _password,
                enabled: !_busy,
                obscure: true,
                helper: 'At least 8 characters, with a letter and a number.',
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                // Re-runs the match check on the second field when this
                // one changes, so correcting it clears the stale
                // complaint below instead of leaving it there.
                onChanged: (_) => _formKey.currentState?.validate(),
              ),
              const SizedBox(height: AppSpacing.xl),
              NovaTextField(
                label: 'Confirm password',
                controller: _confirmPassword,
                enabled: !_busy,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) =>
                    Validators.confirmPassword(value, _password.text),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _ConsentCheckbox(
                value: _agreedToTerms,
                showError: _showConsentError,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _agreedToTerms = value;
                        if (value) _showConsentError = false;
                      }),
              ),
              const SizedBox(height: AppSpacing.xxl),
              NovaInlineError(
                message:
                    _formError ??
                    (_showConsentError
                        ? 'You need to accept the terms before we can '
                              'create the account.'
                        : null),
              ),
              NovaPrimaryButton(
                label: 'Create account',
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              NovaTextAction(
                leading: 'Already have an account? ',
                label: 'Log in',
                onPressed: _busy || !context.canPop() ? null : context.pop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The consent tick and its copy.
///
/// The wording is the study's disclosure, not marketing text — it says
/// plainly that GPS goes to emergency contacts and the operator during an
/// SOS. Both documents are one tap away, because consent to something
/// nobody can read is not consent.
class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.showError,
    required this.onChanged,
  });

  final bool value;
  final bool showError;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final linkStyle = AppTypography.caption.copyWith(
      color: colors.action,
      fontWeight: FontWeight.w600,
    );

    void open(LegalDocument document) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocumentPage(document: document)),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
            side: BorderSide(
              color: showError ? colors.critical : colors.borderStrong,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RichText(
              text: TextSpan(
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => open(LegalDocument.terms),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => open(LegalDocument.privacy),
                  ),
                  const TextSpan(
                    text:
                        ', including sharing my GPS location with my '
                        'emergency contacts and ride-hailing operator '
                        'during an SOS.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
