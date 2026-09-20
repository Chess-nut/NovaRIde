import 'dart:async';

import 'package:flutter/material.dart';
import 'package:novaride/admin/data/fleet_bootstrap.dart';
import 'package:novaride/admin/screens/admin_alerts_page.dart';
import 'package:novaride/admin/screens/admin_login_page.dart';
import 'package:novaride/admin/screens/dashboard_page.dart';
import 'package:novaride/admin/screens/reports_page.dart';
import 'package:novaride/admin/screens/rider_monitoring_page.dart';
import 'package:novaride/admin/screens/user_management_page.dart';
import 'package:novaride/admin/state/admin_session.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/admin/widgets/admin_sidebar.dart';
import 'package:novaride/shared/theme.dart';

/// Lets a page ask the shell to switch tabs.
///
/// Only cross-tab navigation lives here — the shell owns which tab is
/// showing, and a page has no other way to reach that state without a router
/// package. Rebuild is never needed, so [updateShouldNotify] is always false.
class AdminNavScope extends InheritedWidget {
  /// Opens the Alerts tab with its search pre-filled, used by the roster's
  /// "View alerts" row action.
  final void Function(String query) openAlertsForRider;

  const AdminNavScope({
    super.key,
    required this.openAlertsForRider,
    required super.child,
  });

  static AdminNavScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminNavScope>();
    assert(scope != null, 'AdminNavScope.of() found no AdminShell ancestor.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AdminNavScope oldWidget) => false;
}

/// One entry in the console: its nav item and the page it shows, kept
/// together so a role-filtered nav can never index into an unfiltered page
/// list. The top bar title reads from the same pair as the visible page.
class _ConsoleTab {
  final AdminNavItem navItem;
  final Widget page;

  const _ConsoleTab(this.navItem, this.page);
}

/// Signed-in console. Mounts the [FleetHost] that holds the live fleet state
/// for the whole session, so every page below reads one controller instead
/// of its own copy, and the [AdminSessionScope] that carries who is signed in.
///
/// It also owns the end of the session. The shell subscribes to
/// `AdminAuth.authStateChanges()` for as long as it is mounted and replaces
/// itself with the login page the moment the stream stops naming [user] —
/// on a sign-out from the sidebar, which goes through `signOut()` and comes
/// back on the same stream, and equally on one the widget tree did not
/// initiate: a revoked refresh token, a disabled account, or another tab
/// signing in as somebody else. Every exit path is the same path, so there
/// is no way to be signed out underneath and still see the board.
class AdminShell extends StatefulWidget {
  final AdminUser user;

  const AdminShell({super.key, required this.user});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  StreamSubscription<AdminUser?>? _authSub;

  /// Set once the return to the login page has been pushed, so a stream
  /// event and the sign-out button cannot both navigate.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final auth = FleetSourceScope.maybeOf(context)?.auth;
    _authSub = auth?.authStateChanges().listen(_onAuthChanged);

    // One-time bootstrap of an empty Firestore, behind a --dart-define.
    // Lives here rather than before runApp because the rules only accept it
    // from a signed-in Super Admin. No-op in every other case; never throws.
    unawaited(FleetBootstrap.seedAfterSignIn(widget.user));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _onAuthChanged(AdminUser? user) {
    // Same operator, still signed in — the normal case, including the
    // current-state event Firebase emits on subscribe.
    if (user != null && user.email == widget.user.email) return;
    _returnToLogin();
  }

  Future<void> _signOut() async {
    final auth = FleetSourceScope.maybeOf(context)?.auth;
    if (auth == null) {
      _returnToLogin();
      return;
    }
    // The stream's null brings us back to the login page. Fall through to a
    // direct return as well, in case the provider ends the session without
    // emitting — belt and braces, guarded by _leaving. A provider that fails
    // to sign out is logged, and the operator still leaves the board; the
    // next sign-in replaces whatever session was left behind.
    try {
      await auth.signOut();
    } catch (error) {
      debugPrint('AdminShell: signOut threw $error');
    }
    _returnToLogin();
  }

  void _returnToLogin() {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminSessionScope(
      user: widget.user,
      child: FleetHost(
        child: _AdminShellFrame(user: widget.user, onLogout: _signOut),
      ),
    );
  }
}

/// Sidebar + topbar frame. Pages are kept alive in an IndexedStack so
/// switching tabs never rebuilds them from scratch — no routing package.
class _AdminShellFrame extends StatefulWidget {
  final AdminUser user;
  final VoidCallback onLogout;

  const _AdminShellFrame({required this.user, required this.onLogout});

  @override
  State<_AdminShellFrame> createState() => _AdminShellFrameState();
}

class _AdminShellFrameState extends State<_AdminShellFrame> {
  int _selectedIndex = 0;

  /// Search text handed to the alerts page by a "View alerts" jump. The token
  /// increments on every request so asking twice for the same rider still
  /// re-applies the filter.
  String? _alertsPrefill;
  int _alertsPrefillToken = 0;

  /// Tabs this role can reach. User Management drops out entirely for
  /// dispatchers and viewers — and because nav items and pages are built as
  /// one list, every index stays in agreement.
  List<_ConsoleTab> get _tabs => [
        const _ConsoleTab(
          AdminNavItem(Icons.dashboard_outlined, 'Dashboard'),
          DashboardPage(),
        ),
        const _ConsoleTab(
          AdminNavItem(Icons.map_outlined, 'Rider Monitoring'),
          RiderMonitoringPage(),
        ),
        if (widget.user.role.canSeeUserManagement)
          const _ConsoleTab(
            AdminNavItem(Icons.people_outline, 'User Management'),
            UserManagementPage(),
          ),
        _ConsoleTab(
          const AdminNavItem(Icons.notifications_none, 'Alerts'),
          AdminAlertsPage(
            prefillQuery: _alertsPrefill,
            prefillToken: _alertsPrefillToken,
          ),
        ),
        const _ConsoleTab(
          AdminNavItem(Icons.insights_outlined, 'Reports'),
          ReportsPage(),
        ),
      ];

  void _openAlertsForRider(String query) {
    final index = _tabs.indexWhere((t) => t.navItem.label == 'Alerts');
    if (index == -1) return;

    setState(() {
      _alertsPrefill = query;
      _alertsPrefillToken++;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Below 900px the sidebar drops to an icon rail so content keeps its room.
    final collapsed = MediaQuery.sizeOf(context).width < 900;
    final tabs = _tabs;

    // A role change can shorten the list; clamp rather than index past its end.
    final index = _selectedIndex.clamp(0, tabs.length - 1);

    return AdminNavScope(
      openAlertsForRider: _openAlertsForRider,
      child: Scaffold(
        backgroundColor: NovaColors.background,
        body: Row(
          children: [
            AdminSidebar(
              items: [for (final tab in tabs) tab.navItem],
              selectedIndex: index,
              onSelect: (i) => setState(() => _selectedIndex = i),
              onLogout: widget.onLogout,
              collapsed: collapsed,
            ),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(tabs[index].navItem.label),
                  Expanded(
                    child: IndexedStack(
                      index: index,
                      children: [for (final tab in tabs) tab.page],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String title) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: NovaColors.card,
        border: Border(bottom: BorderSide(color: NovaColors.cardBorder)),
      ),
      child: Row(
        children: [
          // The title yields to the status cluster on narrow viewports rather
          // than the row overflowing — the chips are what an operator needs.
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const _SourceChip(),
          const SizedBox(width: 10),
          const _ConnectionPill(),
          const SizedBox(width: 16),
          _buildAdminChip(),
        ],
      ),
    );
  }

  Widget _buildAdminChip() {
    final user = widget.user;

    return Tooltip(
      message: '${user.email} · ${user.role.label}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: NovaColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NovaColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: NovaColors.pink,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                user.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              user.name,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 9),
            _buildRoleBadge(user.role),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(AdminRole role) {
    final color = switch (role) {
      AdminRole.superAdmin => NovaColors.green,
      AdminRole.dispatcher => NovaColors.cyan,
      AdminRole.viewer => NovaColors.secondaryText,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        role.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Names the data source in the top bar: `FIRESTORE` or `SIMULATION`.
///
/// Exists so a demo can prove at a glance that the board is real — and so
/// nobody can present the simulation while believing it is Firebase. Its
/// own widget rather than a helper on the frame, so a fleet tick rebuilds
/// this chip and not the whole shell.
class _SourceChip extends StatelessWidget {
  const _SourceChip();

  @override
  Widget build(BuildContext context) {
    final fleet = FleetScope.of(context);
    final source = fleet.source;
    final color = switch (source) {
      FleetSource.firestore => NovaColors.cyan,
      FleetSource.simulation => NovaColors.amber,
    };
    final icon = switch (source) {
      FleetSource.firestore => Icons.cloud_outlined,
      FleetSource.simulation => Icons.science_outlined,
    };
    // The project id comes from the loaded config, never from a literal here,
    // so this tooltip cannot drift from the project the console is actually
    // talking to.
    final projectId = FleetSourceScope.maybeOf(context)?.projectId;
    final tooltip = switch (source) {
      FleetSource.firestore when projectId != null =>
        'Live data from Cloud Firestore (project $projectId)',
      FleetSource.firestore => 'Live data from Cloud Firestore',
      FleetSource.simulation =>
        'In-process simulation — no Firebase config found',
    };

    // Below 1000px the label goes and the icon carries the meaning; the
    // tooltip still spells it out.
    final compact = MediaQuery.sizeOf(context).width < 1000;

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                source.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Link health: `LIVE`, `CONNECTING` or `OFFLINE`, from the repository's
/// own report (snapshot metadata for Firestore) rather than guessed from
/// failures. The tooltip carries the reason when something is wrong.
class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill();

  @override
  Widget build(BuildContext context) {
    final connection = FleetScope.of(context).connection;
    final (label, color) = switch (connection.state) {
      FleetConnectionState.connected => ('LIVE', NovaColors.green),
      FleetConnectionState.connecting => ('CONNECTING', NovaColors.amber),
      FleetConnectionState.disconnected => ('OFFLINE', NovaColors.red),
    };

    return Tooltip(
      message: connection.message ?? 'Receiving updates from the data source',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: color, size: 8),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
