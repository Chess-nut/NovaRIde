import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../screens/home_page.dart';
import '../screens/analytics_page.dart';
import '../screens/profile_page.dart';

/// Bottom navigation bar: Home, Analytics, Profile.
///
/// Lives here rather than inside a screen so every rider screen can reuse it
/// without importing another screen — it just needs to be told which tab is
/// currently selected.
class NovaBottomNavBar extends StatelessWidget {
  final int selectedIndex;

  const NovaBottomNavBar({super.key, required this.selectedIndex});

  void _onTabTapped(BuildContext context, int index) {
    if (index == selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(_noAnimationRoute(const HomePage()));
        break;
      case 1:
        Navigator.of(context).pushReplacement(_noAnimationRoute(const AnalyticsPage()));
        break;
      case 2:
        Navigator.of(context).pushReplacement(_noAnimationRoute(const ProfilePage()));
        break;
      default:
        break;
    }
  }

  /// A page route with no transition animation — the new screen just
  /// appears instantly, like switching tabs rather than "navigating".
  static Route _noAnimationRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
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
              icon: Icons.home_filled,
              label: 'HOME',
              selected: selectedIndex == 0,
              onTap: () => _onTabTapped(context, 0),
            ),
            _NavItem(
              icon: Icons.show_chart,
              label: 'ANALYTICS',
              selected: selectedIndex == 1,
              onTap: () => _onTabTapped(context, 1),
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'PROFILE',
              selected: selectedIndex == 2,
              onTap: () => _onTabTapped(context, 2),
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
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? NovaColors.cyan : NovaColors.secondaryText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
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
    );
  }
}
