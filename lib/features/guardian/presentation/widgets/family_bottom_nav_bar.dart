import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:novaride/core/constants/app_routes.dart';
import 'package:novaride/shared/theme.dart';

class FamilyBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool showAlertBadge;

  const FamilyBottomNavBar({
    super.key,
    required this.selectedIndex,
    this.showAlertBadge = false,
  });

  // The tabs used to be `Navigator.pushReplacementNamed` against the route
  // table on MaterialApp. MaterialApp.router has no such table, so they go
  // through go_router now. `go` rather than `push`, to keep the old
  // behaviour: a tab replaces the screen instead of stacking on it.
  void _onTap(BuildContext context, int index) {
    if (index == selectedIndex) return;
    const paths = [
      AppRoutes.guardianHomePath,
      AppRoutes.guardianMapPath,
      AppRoutes.guardianAlertsPath,
      AppRoutes.guardianHistoryPath,
      AppRoutes.guardianProfilePath,
    ];
    if (index < 0 || index >= paths.length) return;
    context.go(paths[index]);
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(
        icon: Icons.home_outlined,
        label: 'Home',
        selected: selectedIndex == 0,
        onTap: () => _onTap(context, 0),
      ),
      _NavItem(
        icon: Icons.map_outlined,
        label: 'Map',
        selected: selectedIndex == 1,
        onTap: () => _onTap(context, 1),
      ),
      _NavItem(
        icon: Icons.notifications_none,
        label: 'Alerts',
        selected: selectedIndex == 2,
        onTap: () => _onTap(context, 2),
        showBadge: showAlertBadge,
      ),
      _NavItem(
        icon: Icons.history_outlined,
        label: 'History',
        selected: selectedIndex == 3,
        onTap: () => _onTap(context, 3),
      ),
      _NavItem(
        icon: Icons.person_outline,
        label: 'Profile',
        selected: selectedIndex == 4,
        onTap: () => _onTap(context, 4),
      ),
    ];

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
          children: items,
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
    final color = selected ? NovaColors.cyan : NovaColors.secondaryText;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (showBadge)
            Positioned(
              right: 2,
              top: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: NovaColors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
