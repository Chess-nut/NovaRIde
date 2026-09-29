import 'package:flutter/material.dart';
import 'package:novaride/core/widgets/nova_brand_mark.dart';
import 'package:novaride/shared/theme.dart';

/// Where a signed-in but unverified account waits.
///
/// Phase 1 ships the screen so the route exists and the redirect that
/// guards it can be tested. The two buttons do nothing yet: "resend" needs
/// `AuthRepository.sendEmailVerification` and "I have verified" needs
/// `reloadUser`, and neither exists before Phase 3. They are disabled
/// rather than absent so the shape of the screen is honest about what it
/// will do.
class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key, this.email});

  /// The address the verification was sent to. Null until real auth can
  /// supply it.
  final String? email;

  @override
  Widget build(BuildContext context) {
    final sentTo = email;

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NovaLogoMark(size: 88),
              const SizedBox(height: 28),
              const NovaWordmark(fontSize: 24),
              const SizedBox(height: 32),
              const Text(
                'Confirm your email',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                sentTo == null
                    ? 'We have sent you a confirmation link. Open it, then '
                        'come back here.'
                    : 'We have sent a confirmation link to $sentTo. Open it, '
                        'then come back here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: null,
                  child: const Text("I have confirmed it"),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: null,
                child: const Text('Send the link again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
