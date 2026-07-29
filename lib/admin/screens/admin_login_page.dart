import 'package:flutter/material.dart';
import 'package:novaride/admin/screens/admin_shell.dart';
import 'package:novaride/shared/theme.dart';

/// Operations console sign-in. Styled to match the rider login screen.
/// Mock credential check only — Firebase Auth arrives in a later phase.
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  static const _validEmail = 'admin@novaride.ph';
  static const _validPassword = 'admin123';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email == _validEmail && password == _validPassword) {
      setState(() => _errorText = null);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminShell()),
      );
    } else {
      setState(() => _errorText = 'Invalid email or password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: NovaColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: NovaColors.cardBorder),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 22),
                    const Text(
                      'NovaRide TNVS Operations',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Fleet safety monitoring console',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NovaColors.secondaryText, fontSize: 13),
                    ),
                    const SizedBox(height: 26),
                    if (_errorText != null) ...[
                      _buildErrorBanner(_errorText!),
                      const SizedBox(height: 16),
                    ],
                    _buildLabel('EMAIL'),
                    const SizedBox(height: 8),
                    _buildEmailField(),
                    const SizedBox(height: 18),
                    _buildLabel('PASSWORD'),
                    const SizedBox(height: 8),
                    _buildPasswordField(),
                    const SizedBox(height: 26),
                    _buildSignInButton(),
                    const SizedBox(height: 18),
                    const Text(
                      'Demo credentials — admin@novaride.ph / admin123',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NovaColors.secondaryText, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: NovaColors.background,
          border: Border.all(color: NovaColors.cyan, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: NovaColors.cyan.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.shield_outlined, color: NovaColors.cyan, size: 34),
      ),
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
    return TextFormField(
      controller: _emailController,
      style: const TextStyle(color: NovaColors.primaryText, fontSize: 15),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration(
        hint: 'admin@novaride.ph',
        icon: Icons.alternate_email,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Email is required';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: NovaColors.primaryText, fontSize: 15),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      decoration: _fieldDecoration(
        hint: 'Enter your password',
        icon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: NovaColors.secondaryText,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Password is required';
        return null;
      },
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: NovaColors.secondaryText, fontSize: 14),
      prefixIcon: Icon(icon, color: NovaColors.secondaryText, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: NovaColors.background,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: border(NovaColors.cardBorder),
      enabledBorder: border(NovaColors.cardBorder),
      focusedBorder: border(NovaColors.cyan),
      errorBorder: border(NovaColors.red),
      focusedErrorBorder: border(NovaColors.red),
      errorStyle: const TextStyle(color: NovaColors.red, fontSize: 11),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: NovaColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: NovaColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: NovaColors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: NovaColors.cyan,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: const Text(
          'SIGN IN',
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
