import 'package:flutter/widgets.dart';

/// Who is signed into the operations console.
///
/// Three roles rather than a single admin, because the console covers two
/// genuinely different jobs — dispatching emergencies and administering the
/// fleet — plus a read-only seat for anyone reviewing the board.
enum AdminRole { superAdmin, dispatcher, viewer }

extension AdminRoleCapabilities on AdminRole {
  String get label => switch (this) {
        AdminRole.superAdmin => 'Super Admin',
        AdminRole.dispatcher => 'Dispatcher',
        AdminRole.viewer => 'Viewer',
      };

  /// Acknowledge / dispatch / resolve an alert.
  bool get canActOnAlerts =>
      this == AdminRole.superAdmin || this == AdminRole.dispatcher;

  /// Add, edit or deactivate riders.
  bool get canManageRiders => this == AdminRole.superAdmin;

  /// The User Management tab is hidden when this is false. Hiding is the
  /// convenience; [canManageRiders] is the actual gate, checked again on the
  /// page itself so visibility is never the only thing standing in the way.
  bool get canSeeUserManagement => canManageRiders;

  /// Shown in a tooltip on every control this role cannot use.
  String get restrictionMessage => switch (this) {
        AdminRole.superAdmin => '',
        AdminRole.dispatcher =>
          'Dispatchers cannot change the rider roster. Sign in as a Super '
              'Admin to manage riders.',
        AdminRole.viewer =>
          'Viewers have read-only access. Sign in as a Dispatcher or Super '
              'Admin to act on alerts.',
      };
}

/// Parses a role as stored in a custom claim or an `admins/{uid}` document.
///
/// The canonical values are the enum names verbatim (`superAdmin`,
/// `dispatcher`, `viewer`). `administrator`/`admin` and `operator` are
/// tolerated on read only, so a claim set by hand with the wrong spelling
/// degrades to the intended role instead of locking the operator out. They
/// are never written. Anything else — including null — is unrecognised, and
/// the caller must treat that as "not provisioned", never as a default role.
AdminRole? parseAdminRole(Object? raw) {
  if (raw is! String) return null;
  return switch (raw.trim()) {
    'superAdmin' || 'administrator' || 'admin' => AdminRole.superAdmin,
    'dispatcher' || 'operator' => AdminRole.dispatcher,
    'viewer' => AdminRole.viewer,
    _ => null,
  };
}

class AdminUser {
  final String name;
  final String email;
  final AdminRole role;

  const AdminUser({
    required this.name,
    required this.email,
    required this.role,
  });

  /// "Ops Admin" → "OA". Used by the top-bar avatar.
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// A demo sign-in, paired with its password.
///
/// Simulation-only. These are the accounts behind `LocalAdminAuth`, the
/// `AdminAuth` implementation the console runs on when no Firebase config is
/// present. On the Firestore path the principal comes from Firebase Auth and
/// the role from a custom claim or `admins/{uid}`; nothing downstream can tell
/// the difference, because both paths hand the shell an [AdminUser].
class AdminAccount {
  final AdminUser user;
  final String password;

  const AdminAccount({required this.user, required this.password});
}

const List<AdminAccount> demoAccounts = [
  AdminAccount(
    user: AdminUser(
      name: 'Ops Admin',
      email: 'admin@novaride.ph',
      role: AdminRole.superAdmin,
    ),
    password: 'admin123',
  ),
  AdminAccount(
    user: AdminUser(
      name: 'Marisol Cruz',
      email: 'dispatch@novaride.ph',
      role: AdminRole.dispatcher,
    ),
    password: 'dispatch123',
  ),
  AdminAccount(
    user: AdminUser(
      name: 'Ramon Bautista',
      email: 'viewer@novaride.ph',
      role: AdminRole.viewer,
    ),
    password: 'viewer123',
  ),
];

/// The operator accounts provisioned in the Firebase project, for the login
/// page's one-tap card on the Firestore path.
///
/// Emails and roles only. The passwords are real credentials and live
/// nowhere in this repository; tapping a row fills the email field and
/// nothing else. The role shown is what `admins/{uid}` says — the console
/// still resolves the real role at sign-in, this list is a convenience for
/// the person at the keyboard, not a source of authority.
const List<({String email, AdminRole role})> provisionedOperators = [
  (email: 'qrlunatal@tip.edu.ph', role: AdminRole.superAdmin),
  (email: 'qhjcagbayani@tip.edu.ph', role: AdminRole.dispatcher),
  (email: 'qdplegarde@tip.edu.ph', role: AdminRole.viewer),
];

/// Returns the matching user, or null when the credentials do not match.
/// Email comparison is case-insensitive; the password is not.
AdminUser? authenticate(String email, String password) {
  final normalized = email.trim().toLowerCase();
  for (final account in demoAccounts) {
    if (account.user.email == normalized && account.password == password) {
      return account.user;
    }
  }
  return null;
}

/// Makes the signed-in user available to every page below the shell.
///
/// A plain [InheritedWidget]: the [user] it carries is fixed for the life of
/// one shell. The session itself is *not* fixed — a Firebase refresh token
/// can be revoked mid-session, an account disabled, or another tab can sign
/// in as someone else — so the shell listens to
/// `AdminAuth.authStateChanges()` and, the moment that stream stops naming
/// this [user] (null, or a different operator), replaces itself with the
/// login page. Pages never see a partially signed-out user; the whole
/// subtree below this scope goes away instead.
class AdminSessionScope extends InheritedWidget {
  final AdminUser user;

  const AdminSessionScope({
    super.key,
    required this.user,
    required super.child,
  });

  static AdminUser of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdminSessionScope>();
    assert(
      scope != null,
      'AdminSessionScope.of() found no AdminShell ancestor. Admin pages must '
      'be mounted below the shell that holds the session.',
    );
    return scope!.user;
  }

  @override
  bool updateShouldNotify(AdminSessionScope oldWidget) =>
      oldWidget.user != user;
}
