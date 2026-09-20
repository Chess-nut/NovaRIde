import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// One tappable row used inside a Profile or Settings card — icon, title,
/// optional subtitle, chevron.
///
/// Shared between [ProfilePage] and [SettingsPage] (and any future screen
/// built the same way) so the two don't drift into slightly different
/// looking rows. Every tile built with this should have a real
/// destination — no decorative dead ends.
class NovaSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const NovaSettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: NovaColors.secondaryText, size: 20),
          ],
        ),
      ),
    );
  }
}

/// A divider that lines up with [NovaSettingsTile]'s icon/text indent.
Widget novaTileDivider() =>
    const Divider(height: 1, color: NovaColors.cardBorder, indent: 56);