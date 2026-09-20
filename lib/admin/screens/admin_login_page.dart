import 'package:flutter/material.dart';
import 'package:novaride/admin/data/admin_auth.dart';
import 'package:novaride/admin/screens/admin_shell.dart';
import 'package:novaride/admin/state/admin_session.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/shared/theme.dart';

/// Operations console sign-in. Styled to match the rider login screen.
///
/// Signs in through whichever [AdminAuth] the enclosing `AdminApp` carries:
/// Firebase Auth on the Firestore path, the local demo accounts on the
/// simulation. The page never learns which — it awaits [AdminAuth.signIn],
/// shows [AdminAuthException.message] verbatim when that throws, and hands
/// the resulting [AdminUser] to the shell. The one visible difference is the
/// credentials card at the bottom, which lists passwords only for the demo
/// accounts, because those are not real credentials.
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String? _errorText;

  /// True from the moment the sign-in button is pressed until the provider
  /// answers. The button is disabled in that window, so a double-click — or
  /// Enter plus a click — cannot start two sign-ins.
  bool _busy = false;

  AdminAuth get _auth => FleetSourceScope.of(context).auth;

  /// Whether the credentials card may show passwords: only for the local
  /// demo accounts, which are not secrets. Real operator passwords never
  /// appear in the UI or the repository.
  bool get _onSimulation => _auth is LocalAdminAuth;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _errorText = null;
    });

    try {
      final user = await _auth.signIn(
        _emailController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AdminShell(user: user)),
      );
    } on AdminAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.message);
    } catch (error, stack) {
      // Anything else is a bug in the provider, not the operator's problem.
      // Log it for the developer; show the operator a sentence.
      debugPrint('AdminLoginPage: sign-in threw $error\n$stack');
      if (!mounted) return;
      setState(() => _errorText = 'Sign-in failed. Try again, and tell a '
          'Super Admin if it keeps happening.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// One-tap fill for the demo card — the defence runs on a projector, and
  /// typing three sets of credentials live is a waste of everyone's time.
  void _useAccount(AdminAccount account) {
    setState(() {
      _emailController.text = account.user.email;
      _passwordController.text = account.password;
      _errorText = null;
    });
  }

  /// Firestore-path counterpart: fills the email only. The operator types
  /// their own password.
  void _useOperator(String email) {
    setState(() {
      _emailController.text = email;
      _passwordController.clear();
      _errorText = null;
    });
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
                    const SizedBox(height: 20),
                    _buildDemoAccountsCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// All three roles, on the login screen itself, so switching roles during
  /// a defence is a single click.
  ///
  /// Simulation: the demo accounts with their passwords, which are not real
  /// credentials. Firestore: the provisioned operator emails with their role
  /// badges — tapping one fills the email field only.
  Widget _buildDemoAccountsCard() {
    final onSimulation = _onSimulation;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            onSimulation ? 'DEMO CREDENTIALS' : 'OPERATOR ACCOUNTS',
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            onSimulation
                ? 'Tap a role to fill the form.'
                : 'Tap a role to fill the email. Passwords are never shown.',
            style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (onSimulation)
            for (final account in demoAccounts) ...[
              _buildAccountRow(
                role: account.user.role,
                email: account.user.email,
                detail: account.password,
                onTap: () => _useAccount(account),
              ),
              if (account != demoAccounts.last) const SizedBox(height: 7),
            ]
          else
            for (final operator in provisionedOperators) ...[
              _buildAccountRow(
                role: operator.role,
                email: operator.email,
                onTap: () => _useOperator(operator.email),
              ),
              if (operator != provisionedOperators.last)
                const SizedBox(height: 7),
            ],
        ],
      ),
    );
  }

  Widget _buildAccountRow({
    required AdminRole role,
    required String email,
    String? detail,
    required VoidCallback onTap,
  }) {
    final color = switch (role) {
      AdminRole.superAdmin => NovaColors.green,
      AdminRole.dispatcher => NovaColors.cyan,
      AdminRole.viewer => NovaColors.secondaryText,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: NovaColors.card,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: NovaColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Text(
                  role.label.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 11.5,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        style: const TextStyle(
                          color: NovaColors.secondaryText,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
        hint: _onSimulation ? 'admin@novaride.ph' : 'operator@tip.edu.ph',
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

  /// Disabled while a sign-in is in flight, with a spinner in place of the
  /// label so the operator can see the console is waiting on the provider
  /// rather than ignoring them.
  Widget _buildSignInButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _busy ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: NovaColors.cyan,
          disabledBackgroundColor: NovaColors.cyan.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.black,
                ),
              )
            : const Text(
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
