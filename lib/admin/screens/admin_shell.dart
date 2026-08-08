import 'package:flutter/material.dart';
import 'package:novaride/admin/screens/admin_alerts_page.dart';
import 'package:novaride/admin/screens/admin_login_page.dart';
import 'package:novaride/admin/screens/dashboard_page.dart';
import 'package:novaride/admin/screens/rider_monitoring_page.dart';
import 'package:novaride/admin/screens/user_management_page.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/admin/widgets/admin_sidebar.dart';
import 'package:novaride/shared/theme.dart';

/// Signed-in console. Owns nothing itself — it mounts the [FleetHost] that
/// holds the live fleet state for the whole session, so every page below
/// reads one controller instead of its own copy.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const FleetHost(child: _AdminShellFrame());
  }
}

/// Sidebar + topbar frame. Pages are kept alive in an IndexedStack so
/// switching tabs never rebuilds them from scratch — no routing package.
class _AdminShellFrame extends StatefulWidget {
  const _AdminShellFrame();

  @override
  State<_AdminShellFrame> createState() => _AdminShellFrameState();
}

class _AdminShellFrameState extends State<_AdminShellFrame> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    DashboardPage(),
    RiderMonitoringPage(),
    UserManagementPage(),
    AdminAlertsPage(),
  ];

  void _handleLogout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    /// Below 900px the sidebar drops to an icon rail so content keeps its room.
    final collapsed = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: Row(
        children: [
          AdminSidebar(
            selectedIndex: _selectedIndex,
            onSelect: (index) => setState(() => _selectedIndex = index),
            onLogout: _handleLogout,
            collapsed: collapsed,
          ),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: _pages),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
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
            adminNavItems[_selectedIndex].label,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
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
            child: const Text(
              'OA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 9),
          const Text(
            'Ops Admin',
            style: TextStyle(color: NovaColors.primaryText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
