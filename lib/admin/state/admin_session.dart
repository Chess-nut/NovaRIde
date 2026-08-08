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
/// Firebase seam: this list is the stand-in for Firebase Auth plus a custom
/// claim carrying the role. Swapping in real auth replaces [demoAccounts] and
/// [authenticate]; everything downstream only ever sees an [AdminUser].
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
/// A plain [InheritedWidget] rather than an InheritedNotifier — the session
/// never changes while signed in. Logging out tears the shell down instead.
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
