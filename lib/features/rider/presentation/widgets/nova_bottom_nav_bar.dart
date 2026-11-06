import 'package:flutter/material.dart';

import 'package:novaride/shared/theme.dart';

import '../pages/alerts_page.dart';
import '../pages/analytics_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';

/// Bottom navigation bar: Home, Analytics, Alerts, Profile — in the
/// original NovaRide look (uppercase labels, cyan for the open tab).
///
/// Lives here rather than inside a screen so every rider screen can reuse
/// it without importing another screen; it only needs to be told which
/// tab is open.
///
/// Two things changed from the old bar, neither visible at a glance: the
/// labels are 12px rather than 9px, so they can be read off a mounted
/// phone, and each tab is a full quarter of the bar at least 56px tall,
/// so a gloved thumb cannot miss it.
class NovaBottomNavBar extends StatelessWidget {
  const NovaBottomNavBar({super.key, required this.selectedIndex});

  final int selectedIndex;

  void _onTabTapped(BuildContext context, int index) {
    if (index == selectedIndex) return;
    final page = switch (index) {
      0 => const HomePage(),
      1 => const AnalyticsPage(),
      2 => const AlertsPage(),
      _ => const ProfilePage(),
    };
    Navigator.of(context).pushReplacement(_noAnimationRoute(page));
  }

  /// A page route with no transition: switching tabs, not navigating.
  static Route<void> _noAnimationRoute(Widget page) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_filled, 'HOME'),
      (Icons.show_chart, 'ANALYTICS'),
      (Icons.notifications_none, 'ALERTS'),
      (Icons.person_outline, 'PROFILE'),
    ];

    // A Material, so a tap's ripple is drawn on the bar's own colour
    // rather than hidden under it.
    return Material(
      color: NovaColors.card,
      shape: const Border(top: BorderSide(color: NovaColors.cardBorder)),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  selected: selectedIndex == i,
                  onTap: () => _onTabTapped(context, i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NovaColors.cyan : NovaColors.secondaryText;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
