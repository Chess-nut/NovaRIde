import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../widgets/nova_settings_tile.dart';
import 'login_page.dart';
import 'profile/notifications_page.dart';
import 'profile/privacy_security_page.dart';
import 'profile/help_support_page.dart';
import 'profile/about_page.dart';

/// "Settings" screen — app-level preferences, as opposed to [ProfilePage]
/// which holds the rider's own details, emergency contacts, and helmet
/// device (per the capstone's module breakdown).
///
/// NOTIFICATIONS, ACCOUNT SETTINGS (password / privacy / delete account),
/// and SUPPORT (help, legal, about) — then logout at the bottom.
///
/// Note: crash-sensitivity threshold, SOS countdown-timer duration, and
/// GPS tracking interval are documented as Settings content too, but are
/// intentionally not built yet — those need real sensor/threshold
/// engineering behind them before they can be more than a placeholder
/// slider, so they're deferred rather than shipped as a dead control.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('NOTIFICATIONS'),
                    const SizedBox(height: 12),
                    _buildCard(context, [
                      NovaSettingsTile(
                        icon: Icons.notifications_none,
                        iconColor: const Color(0xFFF5A623),
                        title: 'Notifications',
                        subtitle: 'Alerts, SMS backup, reports',
                        onTap: () => _push(context, const NotificationsPage()),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('ACCOUNT SETTINGS'),
                    const SizedBox(height: 12),
                    _buildCard(context, [
                      NovaSettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: NovaColors.purple,
                        title: 'Account Settings',
                        subtitle: 'Password, privacy, delete account',
                        onTap: () => _push(context, const PrivacySecurityPage()),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('SUPPORT'),
                    const SizedBox(height: 12),
                    _buildCard(context, [
                      NovaSettingsTile(
                        icon: Icons.help_outline,
                        iconColor: NovaColors.cyan,
                        title: 'Help & Support',
                        subtitle: 'FAQs and contact options',
                        onTap: () => _push(context, const HelpSupportPage()),
                      ),
                      novaTileDivider(),
                      NovaSettingsTile(
                        icon: Icons.info_outline,
                        iconColor: NovaColors.secondaryText,
                        title: 'About NovaRide',
                        subtitle: 'Version, terms, privacy policy',
                        onTap: () => _push(context, const AboutPage()),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back, color: NovaColors.primaryText, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage your app preferences',
                style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: NovaColors.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildCard(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: () => _confirmLogout(context),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: NovaColors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: NovaColors.red, size: 18),
            SizedBox(width: 8),
            Text(
              'Log Out',
              style: TextStyle(
                color: NovaColors.red,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NovaColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(color: NovaColors.primaryText, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to log out of NovaRide?',
          style: TextStyle(color: NovaColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: NovaColors.secondaryText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Log Out', style: TextStyle(color: NovaColors.red)),
          ),
        ],
      ),
    );
  }
}