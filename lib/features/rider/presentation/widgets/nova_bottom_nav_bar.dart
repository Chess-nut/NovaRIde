import 'package:flutter/material.dart';

import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/theme/app_typography.dart';

import '../pages/alerts_page.dart';
import '../pages/analytics_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';

/// Bottom navigation bar: Home, Analytics, Alerts, Profile.
///
/// Lives here rather than inside a screen so every rider screen can reuse it
/// without importing another screen — it just needs to be told which tab is
/// currently selected.
///
/// On Signal: 12px sentence-case labels (they were 9px capitals), each tab
/// a full-height 48px+ target with a button role, and the selected tab
/// marked by a pill behind its icon and brighter text rather than by
/// colour alone. Green is not used here — in Signal green means "safe".
class NovaBottomNavBar extends StatelessWidget {
  final int selectedIndex;

  const NovaBottomNavBar({super.key, required this.selectedIndex});

  static const _tabs = [
    (Icons.home_outlined, 'Home'),
    (Icons.show_chart, 'Analytics'),
    (Icons.notifications_none, 'Alerts'),
    (Icons.person_outline, 'Profile'),
  ];

  void _onTabTapped(BuildContext context, int index) {
    if (index == selectedIndex) return;

    final Widget page = switch (index) {
      0 => const HomePage(),
      1 => const AnalyticsPage(),
      2 => const AlertsPage(),
      _ => const ProfilePage(),
    };
    Navigator.of(context).pushReplacement(_noAnimationRoute(page));
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
    final colors = context.colors;

    return Material(
      color: colors.surfaceRaised,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _tabs[i].$1,
                    label: _tabs[i].$2,
                    selected: selectedIndex == i,
                    onTap: () => _onTabTapped(context, i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.textPrimary : colors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? colors.border : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
