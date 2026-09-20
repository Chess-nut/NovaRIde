import 'package:flutter/material.dart';
import 'package:novaride/admin/console_build.dart';
import 'package:novaride/admin/data/admin_auth.dart';
import 'package:novaride/admin/data/browser_storage.dart';
import 'package:novaride/admin/screens/admin_shell.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/shared/theme.dart';

/// TNVS Operator sign-in.
///
/// Signs in through whichever [AdminAuth] the enclosing `AdminApp` carries —
/// Firebase Auth on the Firestore path, the local demo accounts on the
/// simulation — and hands the resulting `AdminUser` to the shell. Errors
/// arrive as [AdminAuthException.message], already written for the operator,
/// and are shown inline verbatim; nothing else the provider says is shown.
///
/// No account is named anywhere on this screen, on either path. The one
/// concession to the person at the keyboard is a "remember email" checkbox
/// that keeps the last address in the browser's local storage — the address
/// only, never the password — so a returning operator lands on the password
/// field. The page's only knowledge of which provider it has is the footer:
/// the simulation says so, in one muted line, so nobody mistakes local mock
/// data for live Firestore. On the Firestore path the footer says nothing,
/// because live is the expected state.
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode(debugLabel: 'login-email');
  final _passwordFocus = FocusNode(debugLabel: 'login-password');
  final _buttonFocus = FocusNode(debugLabel: 'login-submit');

  /// Loose on purpose: something, an `@`, something, a dot, something. The
  /// point is to catch a typo before it costs a Firebase round-trip, not to
  /// implement RFC 5322 — the provider has the final word on validity.
  static final _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool _obscurePassword = true;
  bool _rememberEmail = false;

  /// Set once in [initState]: the email was prefilled from storage, so the
  /// cursor should start on the password instead.
  bool _emailWasRemembered = false;

  /// The sign-in error, shown inline above the fields. Cleared the moment
  /// the operator types again: typing is how they say "let me retry".
  String? _errorText;

  /// Last texts seen by [_onFieldChanged], so it can tell typing from a
  /// cursor move — a controller notifies for both.
  String _lastEmail = '';
  String _lastPassword = '';

  /// True from the moment the sign-in button is pressed until the provider
  /// answers. The button is disabled in that window, so a double-click — or
  /// Enter plus a click — cannot start two sign-ins.
  bool _busy = false;

  AdminAuth get _auth => FleetSourceScope.of(context).auth;

  /// Presentation only: decides the footer line and the email hint's domain.
  bool get _onSimulation => _auth is LocalAdminAuth;

  /// The button enables when both fields have something in them. Enter still
  /// works before that — it runs validation, which is how an empty field
  /// gets its message.
  bool get _formFilled =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final remembered = RememberedEmail.load();
    if (remembered != null) {
      _emailController.text = remembered;
      _rememberEmail = true;
      _emailWasRemembered = true;
    }
    _lastEmail = _emailController.text;
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _emailFocus.addListener(_onEmailFocusChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }

  /// Typing in either field clears the sign-in error and re-evaluates the
  /// button. Selection changes are ignored: [_selectPasswordForRetry] moves
  /// the cursor right after an error is shown, and that must not clear it.
  void _onFieldChanged() {
    final email = _emailController.text;
    final password = _passwordController.text;
    if (email == _lastEmail && password == _lastPassword) return;
    _lastEmail = email;
    _lastPassword = password;
    setState(() => _errorText = null);
  }

  /// An email field that is already showing a message re-checks itself on
  /// every keystroke, so the message goes away the moment the address is
  /// well-formed rather than lingering until the next blur. Hooked to the
  /// field's own `onChanged`, not the controller, because that fires after
  /// the form field has taken the new value; the controller notifies before.
  void _onEmailChanged(String _) {
    final emailState = _emailFieldKey.currentState;
    if (emailState != null && emailState.hasError) emailState.validate();
  }

  /// Validates the email on blur — but only when there is something to
  /// check. Tabbing through an empty field is not a mistake yet; submitting
  /// with it empty is, and submit handles that.
  void _onEmailFocusChanged() {
    if (_emailFocus.hasFocus) return;
    if (_emailController.text.trim().isEmpty) return;
    _emailFieldKey.currentState?.validate();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!_emailShape.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    return null;
  }

  /// Enter in the email field: move on to the password if it is still
  /// empty, otherwise submit — the password manager may already have
  /// filled it.
  void _onEmailSubmitted(String _) {
    if (_passwordController.text.isEmpty) {
      _passwordFocus.requestFocus();
      return;
    }
    _handleLogin();
  }

  Future<void> _handleLogin() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) {
      // Put the cursor on the first field that needs attention.
      if (_emailFieldKey.currentState!.hasError) {
        _emailFocus.requestFocus();
      } else {
        _passwordFocus.requestFocus();
      }
      return;
    }

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
      if (_rememberEmail) {
        RememberedEmail.save(_emailController.text);
      } else {
        RememberedEmail.clear();
      }
      // Replacing the route disposes the AutofillGroup below, which commits
      // the autofill context — that is what makes the browser offer to save
      // the credentials. A failed sign-in never reaches here, so the browser
      // is never asked to save a password that did not work.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AdminShell(user: user)),
      );
    } on AdminAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.message);
      _selectPasswordForRetry();
    } catch (error, stack) {
      // Anything else is a bug in the provider, not the operator's problem.
      // Log it for the developer; show the operator a sentence.
      debugPrint('AdminLoginPage: sign-in threw $error\n$stack');
      if (!mounted) return;
      setState(() => _errorText = 'Sign-in failed. Try again, and tell a '
          'Super Admin if it keeps happening.');
      _selectPasswordForRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// After a refusal the likeliest fix is the password, so the cursor goes
  /// there with the old one selected: typing replaces it, nothing to clear.
  void _selectPasswordForRetry() {
    _passwordFocus.requestFocus();
    _passwordController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _passwordController.text.length,
    );
  }

  void _setRememberEmail(bool value) {
    setState(() => _rememberEmail = value);
    // Unticking is a request to forget, honoured immediately rather than on
    // the next successful sign-in — which may never come on this machine.
    if (!value) RememberedEmail.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            // Wide enough for an institutional address on one line, narrow
            // enough not to sprawl on a 1080p monitor. The card and its
            // footer share the width so the footer reads as part of it.
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCard(),
                const SizedBox(height: 16),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      // Tab order is email → password → sign in, then the two secondary
      // controls (show password, remember email). Reading order would put
      // the eye toggle and the checkbox between password and the button,
      // which is two extra Tabs on the path every operator takes every
      // time; the secondary controls stay reachable, just after.
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLogo(),
                const SizedBox(height: 16),
                const Text(
                  'NovaRide TNVS Operations',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Operator sign-in',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                if (_errorText != null) ...[
                  _buildErrorBanner(_errorText!),
                  const SizedBox(height: 14),
                ],
                _buildLabel('EMAIL'),
                const SizedBox(height: 6),
                _buildEmailField(),
                const SizedBox(height: 14),
                _buildLabel('PASSWORD'),
                const SizedBox(height: 6),
                _buildPasswordField(),
                const SizedBox(height: 8),
                _buildRememberEmail(),
                const SizedBox(height: 12),
                _buildSignInButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 56,
        height: 56,
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
        child: const Icon(
          Icons.shield_outlined,
          color: NovaColors.cyan,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    // Decorative: the fields carry their own semantic labels, so a screen
    // reader is not told "EMAIL" twice.
    return ExcludeSemantics(
      child: Text(
        text,
        style: const TextStyle(
          color: NovaColors.secondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(1),
      child: Semantics(
        label: 'Email address',
        child: TextFormField(
          key: _emailFieldKey,
          controller: _emailController,
          focusNode: _emailFocus,
          autofocus: !_emailWasRemembered,
          autofillHints: const [AutofillHints.username],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: _onEmailChanged,
          onFieldSubmitted: _onEmailSubmitted,
          validator: _validateEmail,
          style: const TextStyle(color: NovaColors.primaryText, fontSize: 15),
          decoration: _fieldDecoration(
            hint: _onSimulation ? 'name@novaride.ph' : 'name@tip.edu.ph',
            icon: Icons.alternate_email,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(2),
      child: Semantics(
        label: 'Password',
        child: TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          autofocus: _emailWasRemembered,
          autofillHints: const [AutofillHints.password],
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleLogin(),
          validator: _validatePassword,
          style: const TextStyle(color: NovaColors.primaryText, fontSize: 15),
          // No hint: the field is labelled, and a hint would be read out
          // as a second label.
          decoration: _fieldDecoration(
            icon: Icons.lock_outline,
            suffixIcon: _buildVisibilityToggle(),
          ),
        ),
      ),
    );
  }

  /// Keyboard-reachable (order 4, after the button) and named for screen
  /// readers through its tooltip, which doubles as the accessible label.
  Widget _buildVisibilityToggle() {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(4),
      child: IconButton(
        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: NovaColors.secondaryText,
          size: 20,
        ),
        style: ButtonStyle(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? const BorderSide(color: NovaColors.cyan, width: 2)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildRememberEmail() {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(5),
      child: MergeSemantics(
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: _rememberEmail,
                onChanged: (value) => _setRememberEmail(value ?? false),
                semanticLabel: 'Remember my email on this browser',
                activeColor: NovaColors.cyan,
                checkColor: NovaColors.background,
                focusColor: NovaColors.cyan.withValues(alpha: 0.3),
                side: WidgetStateBorderSide.resolveWith(
                  (states) => BorderSide(
                    color: states.contains(WidgetState.focused) ||
                            states.contains(WidgetState.selected)
                        ? NovaColors.cyan
                        : NovaColors.secondaryText,
                    width: states.contains(WidgetState.focused) ? 2 : 1.5,
                  ),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setRememberEmail(!_rememberEmail),
                child: const Text(
                  'Remember my email on this browser',
                  style: TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: NovaColors.secondaryText, fontSize: 14),
      prefixIcon: Icon(icon, color: NovaColors.secondaryText, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: NovaColors.background,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: border(NovaColors.cardBorder),
      enabledBorder: border(NovaColors.cardBorder),
      // A 2px accent border is the focus ring for the fields: visible from
      // the back of a room, and the accent clears 3:1 against both the field
      // fill and the card around it.
      focusedBorder: border(NovaColors.cyan, width: 2),
      errorBorder: border(NovaColors.red),
      focusedErrorBorder: border(NovaColors.red, width: 2),
      errorStyle: const TextStyle(color: NovaColors.red, fontSize: 11.5),
    );
  }

  Widget _buildErrorBanner(String message) {
    // A live region, so a screen reader announces the message when it
    // appears instead of waiting to be asked.
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: NovaColors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NovaColors.red.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, color: NovaColors.red, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: NovaColors.red,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Disabled until both fields are filled, and again while a sign-in is in
  /// flight — with a spinner in place of the label so the operator can see
  /// the console is waiting on the provider rather than ignoring them.
  Widget _buildSignInButton() {
    final enabled = _formFilled && !_busy;
    return FocusTraversalOrder(
      order: const NumericFocusOrder(3),
      child: _FocusRing(
        focusNode: _buttonFocus,
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            focusNode: _buttonFocus,
            onPressed: enabled ? _handleLogin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: NovaColors.cyan,
              foregroundColor: NovaColors.background,
              // In flight the button keeps its colour, dimmed, so the
              // spinner reads as "working"; unfilled it drops to the border
              // grey so it reads as "not yet".
              disabledBackgroundColor: _busy
                  ? NovaColors.cyan.withValues(alpha: 0.55)
                  : NovaColors.cardBorder,
              disabledForegroundColor: NovaColors.secondaryText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: NovaColors.background,
                      semanticsLabel: 'Signing in',
                    ),
                  )
                : const Text(
                    'SIGN IN',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Version and build, and — on the simulation only — a line saying so.
  Widget _buildFooter() {
    const muted = TextStyle(color: NovaColors.secondaryText, fontSize: 11.5);
    return Column(
      children: [
        if (_onSimulation) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: NovaColors.secondaryText,
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Simulation mode — local data, not live Firestore',
                  textAlign: TextAlign.center,
                  style: muted.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Text(
          'NovaRide Operations Console $consoleVersionLabel',
          textAlign: TextAlign.center,
          style: muted,
        ),
      ],
    );
  }
}

/// Draws a ring around [child] while [focusNode] has keyboard focus.
///
/// Material's own focus treatment on a filled button is a faint tint of the
/// label colour, which disappears on a projector. This is a 2px ring in the
/// accent colour, separated from the button by a gap of card background, so
/// it is visible from across a room and clears the 3:1 non-text contrast
/// requirement against the card — which a ring drawn on the button's own
/// edge, next to the accent fill, could not.
///
/// Shown only in traditional (keyboard) highlight mode, the same rule
/// Material applies to its focus highlights, so a touch tap does not leave a
/// ring behind.
class _FocusRing extends StatefulWidget {
  const _FocusRing({required this.focusNode, required this.child});

  final FocusNode focusNode;
  final Widget child;

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_update);
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void didUpdateWidget(_FocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_update);
      widget.focusNode.addListener(_update);
      _update();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_update);
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode _) => _update();

  void _update() {
    final visible = widget.focusNode.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (visible != _visible && mounted) setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: NovaColors.cyan.withValues(alpha: _visible ? 1 : 0),
          width: 2,
        ),
      ),
      child: widget.child,
    );
  }
}
