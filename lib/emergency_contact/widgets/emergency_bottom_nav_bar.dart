import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../screens/rider_dashboard_page.dart';
import '../screens/rider_map_page.dart';
import '../screens/emergency_alert_page.dart';
import '../screens/incident_history_page.dart';
import '../screens/profile_page.dart';

/// Bottom navigation for the Emergency Contact side of the app:
/// Dashboard, Map, Alerts, History, Profile.
///
/// Lives in its own `emergency_contact/` module (parallel to `rider/` and
/// `admin/`) rather than inside `rider/`, since this is a distinct actor
/// with its own dashboard, not a rider feature.
class EmergencyBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool showAlertBadge;

  const EmergencyBottomNavBar({super.key, required this.selectedIndex, this.showAlertBadge = false});

  void _onTabTapped(BuildContext context, int index) {
    if (index == selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RiderDashboardPage()),
        );
        break;
      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RiderMapPage()),
        );
        break;
      case 2:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmergencyAlertPage()),
        );
        break;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const IncidentHistoryPage()),
        );
        break;
      case 4:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NovaColors.card,
        border: Border(top: BorderSide(color: NovaColors.cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.dashboard_outlined,
              label: 'DASHBOARD',
              selected: selectedIndex == 0,
              onTap: () => _onTabTapped(context, 0),
            ),
            _NavItem(
              icon: Icons.map_outlined,
              label: 'MAP',
              selected: selectedIndex == 1,
              onTap: () => _onTabTapped(context, 1),
            ),
            _NavItem(
              icon: Icons.warning_amber_outlined,
              label: 'ALERTS',
              selected: selectedIndex == 2,
              onTap: () => _onTabTapped(context, 2),
              showBadge: showAlertBadge,
            ),
            _NavItem(
              icon: Icons.history_outlined,
              label: 'HISTORY',
              selected: selectedIndex == 3,
              onTap: () => _onTabTapped(context, 3),
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'PROFILE',
              selected: selectedIndex == 4,
              onTap: () => _onTabTapped(context, 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? NovaColors.pink : NovaColors.secondaryText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (showBadge)
            Positioned(
              right: 0,
              top: -2,
              child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: NovaColors.red, shape: BoxShape.circle)),
            ),
        ],
      ),
    );
  }
}