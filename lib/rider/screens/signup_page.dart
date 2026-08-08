import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:novaride/shared/theme.dart';
import 'legal_document_page.dart';
import 'role_selection_page.dart';

/// Sign up screen for NovaRide.
///
/// There is no backend yet, so this screen only validates the form
/// locally and then sends the user back to the Login screen, where the
/// only account that can actually log in is the hardcoded one:
///   username: admin
///   password: admin123
///
/// [role] comes from RoleSelectionPage and decides the header copy below.
/// The form fields are the same for both roles for now — Phase 2 is
/// where a real backend would branch riders into the crash-detection
/// dashboard and emergency contacts into the rider-monitoring dashboard.
class SignupPage extends StatefulWidget {
  final UserRole role;

  const SignupPage({super.key, this.role = UserRole.rider});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _showConsentError = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      setState(() => _showConsentError = true);
      return;
    }

    setState(() => _isLoading = true);

    // Simulate account creation (no backend yet).
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: NovaColors.card,
        behavior: SnackBarBehavior.floating,
        content: Text(
          widget.role == UserRole.rider
              ? 'Rider account created! Please log in with admin / admin123.'
              : 'Emergency contact account created! Please log in with admin / admin123.',
          style: const TextStyle(color: NovaColors.primaryText),
        ),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.role == UserRole.rider
                            ? 'Create Rider Account'
                            : 'Create Emergency Contact Account',
                        style: const TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.role == UserRole.rider
                            ? 'Set up your rider profile to get started'
                            : "Set up your account to watch over your rider",
                        style: const TextStyle(
                          color: NovaColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildRoleChip(context),
                      const SizedBox(height: 24),
                      _buildLabel('FULL NAME'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _fullNameController,
                        hint: 'FirstName MiddleName LastName',
                        icon: Icons.badge_outlined,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('USERNAME'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _usernameController,
                        hint: 'Choose a username',
                        icon: Icons.person_outline,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('EMAIL'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailPattern.hasMatch(v.trim())) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('PASSWORD'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _passwordController,
                        hint: 'Create a password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: NovaColors.secondaryText,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 6) return 'Use at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('CONFIRM PASSWORD'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hint: 'Re-enter your password',
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: NovaColors.secondaryText,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm your password';
                          if (v != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 26),
                      _buildConsentRow(),
                      const SizedBox(height: 20),
                      _buildSignUpButton(),
                      const SizedBox(height: 20),
                      _buildLoginRow(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: NovaColors.primaryText),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
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
        children: [
          Icon(
            isRider ? Icons.sports_motorsports : Icons.family_restroom,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isRider ? 'Signing up as Rider' : 'Signing up as Emergency Contact',
              style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: NovaColors.primaryText, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
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
        errorStyle: const TextStyle(color: NovaColors.red, fontSize: 11),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignUp,
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
                'SIGN UP',
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

  Widget _buildConsentRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _agreedToTerms = !_agreedToTerms;
            if (_agreedToTerms) _showConsentError = false;
          }),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _agreedToTerms,
                    onChanged: (v) => setState(() {
                      _agreedToTerms = v ?? false;
                      if (_agreedToTerms) _showConsentError = false;
                    }),
                    activeColor: NovaColors.cyan,
                    checkColor: Colors.black,
                    side: BorderSide(
                      color: _showConsentError ? NovaColors.red : NovaColors.cardBorder,
                      width: 1.5,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: const TextStyle(
                          color: NovaColors.cyan,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LegalDocumentPage(document: LegalDocument.terms),
                                ),
                              ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: NovaColors.cyan,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LegalDocumentPage(document: LegalDocument.privacy),
                                ),
                              ),
                      ),
                      const TextSpan(
                        text: ', including sharing my GPS location with my emergency '
                            'contacts and ride-hailing operator during an SOS.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showConsentError) ...[
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 32),
            child: Text(
              'Please agree to the Terms of Service and Privacy Policy to continue.',
              style: TextStyle(color: NovaColors.red, fontSize: 11.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoginRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(color: NovaColors.secondaryText, fontSize: 13),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Text(
            'Log In',
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