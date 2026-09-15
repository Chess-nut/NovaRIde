import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

class AdminNavItem {
  final IconData icon;
  final String label;
  const AdminNavItem(this.icon, this.label);
}

/// Every tab the console can show, in order. The shell builds a role-filtered
/// subset of these paired with their pages — it does not index into this list,
/// so nothing desynchronises when User Management is hidden.
const adminNavItems = <AdminNavItem>[
  AdminNavItem(Icons.dashboard_outlined, 'Dashboard'),
  AdminNavItem(Icons.map_outlined, 'Rider Monitoring'),
  AdminNavItem(Icons.people_outline, 'User Management'),
  AdminNavItem(Icons.notifications_none, 'Alerts'),
  AdminNavItem(Icons.insights_outlined, 'Reports'),
];

/// Persistent left navigation for the operations console.
/// Collapses to an icon rail below 900px so the shell stays usable on a
/// smaller laptop screen.
class AdminSidebar extends StatelessWidget {
  /// The tabs this role can reach, already filtered by the shell.
  final List<AdminNavItem> items;

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final bool collapsed;

  const AdminSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    this.collapsed = false,
  });

  static const double expandedWidth = 240;
  static const double collapsedWidth = 72;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: collapsed ? collapsedWidth : expandedWidth,
      decoration: const BoxDecoration(
        color: NovaColors.card,
        border: Border(right: BorderSide(color: NovaColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrand(),
          const Divider(height: 1, color: NovaColors.cardBorder),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) _buildNavItem(items[i], i),
          const Spacer(),
          const Divider(height: 1, color: NovaColors.cardBorder),
          _buildLogout(),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 16 : 18),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: NovaColors.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.shield_outlined, color: NovaColors.cyan, size: 19),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NovaRide',
                    style: TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'OPERATIONS',
                    style: TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(AdminNavItem item, int index) {
    final selected = index == selectedIndex;
    final color = selected ? NovaColors.cyan : NovaColors.secondaryText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? NovaColors.cyan.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: () => onSelect(index),
          borderRadius: BorderRadius.circular(9),
          child: Tooltip(
            message: collapsed ? item.label : '',
            child: Container(
              height: 42,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
              child: Row(
                mainAxisAlignment:
                    collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(item.icon, color: color, size: 19),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? NovaColors.primaryText : color,
                          fontSize: 13.5,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: NovaColors.cyan,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(9),
          child: Tooltip(
            message: collapsed ? 'Logout' : '',
            child: Container(
              height: 42,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
              child: Row(
                mainAxisAlignment:
                    collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const Icon(Icons.logout, color: NovaColors.pink, size: 18),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    const Text(
                      'Logout',
                      style: TextStyle(color: NovaColors.pink, fontSize: 13.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
