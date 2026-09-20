import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:novaride/admin/data/admin_auth.dart';
import 'package:novaride/admin/state/admin_session.dart';

/// Firebase Auth sign-in for the TNVS Operator console.
///
/// The principal is a Firebase Auth email/password account. The role is
/// resolved in this order, and the first hit wins:
///
/// 1. the `role` custom claim on the ID token (set with
///    `tool/set_admin_claims.mjs`; the security rules read the same claim);
/// 2. the `role` field of `admins/{uid}`, for accounts with no claim yet —
///    the only role source until claims are set, so it must work alone;
/// 3. **neither → denied.** The Firebase session is ended and [signIn]
///    throws [notProvisionedMessage]. There is deliberately no default role:
///    a quiet `viewer` grant to an unknown account is a security failure that
///    nobody would notice, and a `superAdmin` grant is one everybody would.
///
/// The display name comes from `admins/{uid}.name`, then Firebase's
/// `displayName`, then the local part of the email.
///
/// Every failure surfaces as an [AdminAuthException] carrying a message
/// written for the operator; provider codes are logged, never shown.
class FirebaseAdminAuth implements AdminAuth {
  /// Both default to the app's singletons. Construct only after
  /// `Firebase.initializeApp` — `FleetBootstrap` does — because reading
  /// `FirebaseAuth.instance` before that throws.
  FirebaseAdminAuth({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// The operator this process last resolved, and the Firebase uid it came
  /// from. Kept so the auth-state stream can answer for the signed-in user
  /// without another round trip, and so a uid change is noticed.
  AdminUser? _current;
  String? _currentUid;

  @override
  AdminUser? get currentUser => _current;

  @override
  Future<AdminUser> signIn(String email, String password) async {
    final UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      debugPrint('FirebaseAdminAuth: sign-in rejected — ${error.code}');
      throw AdminAuthException(messageForFirebaseCode(error.code));
    }

    final user = credential.user;
    if (user == null) {
      // The SDK contract says this cannot happen for a successful
      // email/password sign-in; treat it as a failed sign-in rather than
      // reason about a session with no user.
      throw const AdminAuthException(signInFailedMessage);
    }

    final AdminUser? operator;
    try {
      operator = await _resolve(user, typedEmail: email.trim());
    } on FirebaseException catch (error) {
      debugPrint('FirebaseAdminAuth: role lookup failed — '
          '${error.plugin}/${error.code}');
      await _auth.signOut();
      throw AdminAuthException(messageForFirebaseCode(error.code));
    } catch (error, stack) {
      debugPrint('FirebaseAdminAuth: role lookup threw $error\n$stack');
      await _auth.signOut();
      throw const AdminAuthException(roleLookupFailedMessage);
    }

    if (operator == null) {
      // Authenticated, but not provisioned for the console. End the Firebase
      // session so a half-signed-in principal is never left behind.
      debugPrint('FirebaseAdminAuth: ${user.uid} has no role claim and no '
          'admins/${user.uid} document — denied.');
      await _auth.signOut();
      throw const AdminAuthException(notProvisionedMessage);
    }

    _current = operator;
    _currentUid = user.uid;
    return operator;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _currentUid = null;
    await _auth.signOut();
  }

  /// Firebase's own `authStateChanges`, mapped to operators.
  ///
  /// It fires on sign-in, on sign-out — including the sign-out the SDK
  /// performs itself when a refresh token has been revoked, which is the case
  /// the shell exists to catch — and on session restore. It does **not** fire
  /// on the hourly token refresh, so a routine refresh never re-resolves the
  /// role; a changed claim reaches the console when the operator signs in
  /// again, which is what the tooling tells them to do.
  @override
  Stream<AdminUser?> authStateChanges() =>
      _auth.authStateChanges().asyncMap(_operatorFor);

  Future<AdminUser?> _operatorFor(User? user) async {
    if (user == null) {
      _current = null;
      _currentUid = null;
      return null;
    }
    if (user.uid == _currentUid && _current != null) return _current;

    // A session this process did not sign in — restored from storage, or
    // switched by another tab. Resolve it exactly as signIn would, and end
    // it if the account is not provisioned.
    try {
      final operator = await _resolve(user, typedEmail: user.email ?? '');
      if (operator == null) {
        debugPrint('FirebaseAdminAuth: restored session ${user.uid} is not '
            'provisioned — signing out.');
        await _auth.signOut();
        return null;
      }
      _current = operator;
      _currentUid = user.uid;
      return operator;
    } catch (error) {
      debugPrint('FirebaseAdminAuth: could not resolve restored session — '
          '$error. Signing out.');
      await _auth.signOut();
      return null;
    }
  }

  /// Claim first, `admins/{uid}` second, null when neither names a role.
  Future<AdminUser?> _resolve(User user, {required String typedEmail}) async {
    final token = await user.getIdTokenResult();
    var role = parseAdminRole(token.claims?['role']);

    // The document is read even when the claim already gave a role, because
    // it carries the display name. In that case a failed read is tolerated —
    // the name is a nicety, the role is not. Always from the server: a role
    // must never come from a stale local cache.
    Map<String, dynamic>? profile;
    try {
      final snapshot = await _db
          .doc('admins/${user.uid}')
          .get(const GetOptions(source: Source.server));
      profile = snapshot.data();
    } on FirebaseException {
      if (role == null) rethrow;
      debugPrint('FirebaseAdminAuth: admins/${user.uid} unreadable; using '
          'the claim and the account name instead.');
    }

    role ??= parseAdminRole(profile?['role']);
    if (role == null) return null;

    final email = _firstNonBlank([user.email, typedEmail]) ?? '';
    final name = _firstNonBlank([
          profile?['name'],
          user.displayName,
          email.split('@').first,
        ]) ??
        'Operator';

    return AdminUser(name: name, email: email, role: role);
  }

  static String? _firstNonBlank(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }
}

/// Fallback when sign-in fails for a reason with no better explanation.
const signInFailedMessage =
    'Sign-in failed. Try again, and tell a Super Admin if it keeps happening.';

/// Fallback when the account signed in but its role could not be read.
const roleLookupFailedMessage =
    "Signed in, but the console could not verify this account's role. Try "
    'again, and tell a Super Admin if it keeps happening.';

/// Turns a `firebase_auth` or `cloud_firestore` error code into a sentence
/// for the person at the keyboard. Never returns the code itself.
///
/// A wrong password and an unknown email land on the same message whatever
/// Firebase reports: with email-enumeration protection on (the default for
/// new projects) both arrive as `invalid-credential` anyway, and the older,
/// distinct codes are mapped to the same sentence so a project with it off
/// does not become an account-enumeration oracle.
String messageForFirebaseCode(String code) {
  return switch (code) {
    // firebase_auth — credentials. One message for a wrong password and an
    // unknown email, on purpose: a message that differs between the two
    // tells an unauthenticated visitor which addresses are registered.
    'wrong-password' ||
    'user-not-found' ||
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'INVALID_LOGIN_CREDENTIALS' =>
      'Incorrect email or password.',
    'invalid-email' => 'That is not a valid email address.',
    'missing-password' => 'Enter your password.',
    'user-disabled' =>
      'This account has been disabled. Ask a Super Admin to re-enable it.',
    'too-many-requests' =>
      'Too many failed attempts. Wait a few minutes before trying again.',
    'operation-not-allowed' =>
      'Email/password sign-in is not enabled for this Firebase project.',
    'user-token-expired' ||
    'user-token-revoked' ||
    'requires-recent-login' ||
    'unauthenticated' =>
      'Your session has expired. Sign in again.',
    // firebase_auth and cloud_firestore — connectivity
    'network-request-failed' || 'unavailable' || 'deadline-exceeded' =>
      'Cannot reach Firebase. Check the connection and try again.',
    // cloud_firestore — the admins/{uid} lookup
    'permission-denied' =>
      "Signed in, but the console was not allowed to read this account's "
          'role. The Firestore security rules may not be deployed yet.',
    _ => signInFailedMessage,
  };
}
