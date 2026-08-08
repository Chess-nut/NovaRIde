import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import 'home_page.dart';
import 'forgot_password_page.dart';
import 'role_selection_page.dart';
import 'signup_page.dart';

/// Login screen for NovaRide.
///
/// Auth is hardcoded for now (no backend yet):
///   username: admin
///   password: admin123
///
/// [role] comes from RoleSelectionPage. Login itself doesn't behave any
/// differently per role (a real backend would already know an existing
/// account's type) — it's carried through only so the "Sign Up" link
/// below can hand it to Signup without asking the person twice.
class LoginPage extends StatefulWidget {
  final UserRole role;

  const LoginPage({super.key, this.role = UserRole.rider});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _validUsername = 'admin';
  static const _validPassword = 'admin123';

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    // Simulate a brief network/auth check.
    await Future.delayed(const Duration(milliseconds: 600));

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username == _validUsername && password == _validPassword) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorText = 'Invalid username or password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  _buildLogo(),
                  const SizedBox(height: 40),
                  const Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Log in to your smart helmet dashboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(child: _buildRoleChip(context)),
                  const SizedBox(height: 18),
                  _buildLabel('USERNAME'),
                  const SizedBox(height: 8),
                  _buildUsernameField(),
                  const SizedBox(height: 20),
                  _buildLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  _buildPasswordField(),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: NovaColors.cyan,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 14),
                    _buildErrorBanner(_errorText!),
                  ],
                  const SizedBox(height: 28),
                  _buildLoginButton(),
                  const SizedBox(height: 20),
                  _buildSignUpRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(BuildContext context) {
    final isRider = widget.role == UserRole.rider;
    final color = isRider ? NovaColors.cyan : NovaColors.pink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRider ? Icons.sports_motorsports : Icons.family_restroom,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isRider ? 'Continuing as Rider' : 'Continuing as Emergency Contact',
            style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              'Change',
              style: TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Circular logo mark ----
  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: NovaColors.card,
          border: Border.all(color: NovaColors.cyan, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: NovaColors.cyan.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.sports_motorsports,
          color: NovaColors.cyan,
          size: 34,
        ),
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

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      style: const TextStyle(color: NovaColors.primaryText, fontSize: 15),
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration(
        hint: 'Enter your username',
        icon: Icons.person_outline,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Username is required';
        }
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
        if (value == null || value.isEmpty) {
          return 'Password is required';
        }
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
      fillColor: NovaColors.card,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: border(NovaColors.cardBorder),
      enabledBorder: border(NovaColors.cardBorder),
      focusedBorder: border(NovaColors.cyan),
      errorBorder: border(NovaColors.red),
      focusedErrorBorder: border(NovaColors.red),
      errorStyle: const TextStyle(height: 0.01, color: Colors.transparent),
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

  Widget _buildLoginButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: NovaColors.cyan,
          disabledBackgroundColor: NovaColors.cyan.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
                'LOG IN',
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

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(color: NovaColors.secondaryText, fontSize: 13),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SignupPage(role: widget.role)),
            );
          },
          child: const Text(
            'Sign Up',
            style: TextStyle(
              color: NovaColors.cyan,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}