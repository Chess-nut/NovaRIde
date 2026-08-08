import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// "Forgot Password" screen — reached from the Login screen.
///
/// Hardcoded for now: any submitted email just flips to a confirmation
/// state after a simulated delay. No real reset email is sent yet —
/// Phase 2 wires this to Firebase Auth's password reset flow.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _emailSent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: NovaColors.primaryText),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _emailSent ? _buildSentState() : _buildFormState(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Enter-your-email form ----
  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NovaColors.card,
              border: Border.all(color: NovaColors.cyan, width: 1.5),
            ),
            child: const Icon(Icons.lock_reset, color: NovaColors.cyan, size: 30),
          ),
          const SizedBox(height: 20),
          const Text(
            'Forgot Password?',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter the email linked to your account and we'll send you a "
            'link to reset your password.',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 28),
          _buildLabel('EMAIL'),
          const SizedBox(height: 8),
          _buildEmailField(),
          const SizedBox(height: 26),
          _buildSendButton(),
        ],
      ),
    );
  }

  // ---- "Check your inbox" confirmation ----
  Widget _buildSentState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NovaColors.green.withValues(alpha: 0.15),
          ),
          child: const Icon(Icons.mark_email_read_outlined, color: NovaColors.green, size: 30),
        ),
        const SizedBox(height: 20),
        const Text(
          'Check Your Email',
          style: TextStyle(
            color: NovaColors.primaryText,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: const TextStyle(color: NovaColors.secondaryText, fontSize: 13.5, height: 1.5),
            children: [
              const TextSpan(text: "We've sent a password reset link to "),
              TextSpan(
                text: _emailController.text.trim(),
                style: const TextStyle(color: NovaColors.primaryText, fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '. Follow the link to choose a new password.'),
            ],
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: NovaColors.cyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text(
              'BACK TO LOG IN',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => setState(() => _emailSent = false),
            child: const Text(
              "Didn't get it? Try another email",
              style: TextStyle(color: NovaColors.cyan, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: NovaColors.secondaryText,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildEmailField() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleSendLink(),
      style: const TextStyle(color: NovaColors.primaryText, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'you@example.com',
        hintStyle: const TextStyle(color: NovaColors.secondaryText, fontSize: 14),
        prefixIcon: const Icon(Icons.email_outlined, color: NovaColors.secondaryText, size: 20),
        filled: true,
        fillColor: NovaColors.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: border(NovaColors.cardBorder),
        enabledBorder: border(NovaColors.cardBorder),
        focusedBorder: border(NovaColors.cyan),
        errorBorder: border(NovaColors.red),
        focusedErrorBorder: border(NovaColors.red),
        errorStyle: const TextStyle(color: NovaColors.red, fontSize: 11),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Email is required';
        final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!emailPattern.hasMatch(value.trim())) return 'Enter a valid email';
        return null;
      },
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSendLink,
        style: ElevatedButton.styleFrom(
          backgroundColor: NovaColors.cyan,
          disabledBackgroundColor: NovaColors.cyan.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Text(
                'SEND RESET LINK',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}