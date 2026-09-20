import 'dart:async';

import 'package:novaride/admin/state/admin_session.dart';

/// Signs a TNVS Operator into the console and says who is signed in.
///
/// Same seam as `FleetRepository`: widgets never call `FirebaseAuth.instance`
/// directly. `FirebaseAdminAuth` is the real thing; [LocalAdminAuth] wraps the
/// demo accounts so the simulation build — and every widget test — signs in
/// without touching the network. `FleetBootstrap` picks one alongside the
/// data source, so there is exactly one Firebase decision at startup.
///
/// Implementations own no widget state. The shell subscribes to
/// [authStateChanges] for the life of a session and the login page calls
/// [signIn]; one instance serves both, held by `AdminApp`.
abstract class AdminAuth {
  /// Resolves to the signed-in operator, or throws an [AdminAuthException]
  /// whose [AdminAuthException.message] is safe to show as-is.
  Future<AdminUser> signIn(String email, String password);

  Future<void> signOut();

  /// Emits the operator on sign-in and `null` on sign-out — including
  /// sign-outs the widget tree did not initiate, such as an expired or
  /// revoked token. The shell returns to the login page on `null`.
  Stream<AdminUser?> authStateChanges();

  AdminUser? get currentUser;
}

/// A sign-in failure with a message written for the person at the keyboard.
///
/// Raw provider strings (`[firebase_auth/invalid-credential] ...`) mean
/// nothing to an operator, so implementations translate before throwing and
/// the login page shows [message] verbatim.
class AdminAuthException implements Exception {
  final String message;

  const AdminAuthException(this.message);

  @override
  String toString() => 'AdminAuthException: $message';
}

/// Message shown when Firebase Auth accepted the credentials but the account
/// carries no role claim and has no `admins/{uid}` document. Shared so the
/// doc, the tests and the UI all say the same thing.
const notProvisionedMessage =
    'This account is not provisioned for the operations console. Ask a '
    'Super Admin to add it to the admins list.';

/// The simulation's sign-in: a string comparison against [demoAccounts].
///
/// Not authentication, and never presented as such — it exists so the
/// console is fully usable with no Firebase project, which is what keeps
/// teammates unblocked and lets the board be demoed offline.
class LocalAdminAuth implements AdminAuth {
  final _changes = StreamController<AdminUser?>.broadcast();
  AdminUser? _current;

  @override
  AdminUser? get currentUser => _current;

  @override
  Stream<AdminUser?> authStateChanges() => _changes.stream;

  @override
  Future<AdminUser> signIn(String email, String password) async {
    final user = authenticate(email, password);
    if (user == null) {
      throw const AdminAuthException('Invalid email or password');
    }
    _current = user;
    _changes.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    if (_current == null) return;
    _current = null;
    _changes.add(null);
  }
}
