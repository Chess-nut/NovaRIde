import 'package:flutter/material.dart';
import 'package:novaride/admin/screens/admin_alerts_page.dart';
import 'package:novaride/admin/screens/admin_login_page.dart';
import 'package:novaride/admin/screens/dashboard_page.dart';
import 'package:novaride/admin/screens/reports_page.dart';
import 'package:novaride/admin/screens/rider_monitoring_page.dart';
import 'package:novaride/admin/screens/user_management_page.dart';
import 'package:novaride/admin/state/admin_session.dart';
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

/// Signed-in console. Owns nothing itself — it mounts the [FleetHost] that
/// holds the live fleet state for the whole session, so every page below
/// reads one controller instead of its own copy, and the [AdminSessionScope]
/// that carries who is signed in.
class AdminShell extends StatelessWidget {
  final AdminUser user;

  const AdminShell({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return AdminSessionScope(
      user: user,
      child: FleetHost(child: _AdminShellFrame(user: user)),
    );
  }
}

/// Sidebar + topbar frame. Pages are kept alive in an IndexedStack so
/// switching tabs never rebuilds them from scratch — no routing package.
class _AdminShellFrame extends StatefulWidget {
  final AdminUser user;

  const _AdminShellFrame({required this.user});

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

  void _handleLogout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
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
              onLogout: _handleLogout,
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
          Text(
            title,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _buildLiveIndicator(),
          const SizedBox(width: 16),
          _buildAdminChip(),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NovaColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NovaColors.green.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: NovaColors.green, size: 8),
          SizedBox(width: 7),
          Text(
            'LIVE',
            style: TextStyle(
              color: NovaColors.green,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
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
