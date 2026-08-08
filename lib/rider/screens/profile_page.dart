import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import 'login_page.dart';
import 'profile/personal_information.dart';
import 'profile/emergency_contacts_page.dart';
import 'profile/helmet_settings_page.dart';
import 'profile/notifications_page.dart';

/// "Profile" screen — rider info, quick stats, account settings, and
/// logout. Opened from the bottom nav bar's PROFILE tab.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildProfileCard(),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildSectionTitle('ACCOUNT'),
              const SizedBox(height: 12),
              _buildAccountCard(context),
              const SizedBox(height: 24),
              _buildSectionTitle('SUPPORT'),
              const SizedBox(height: 12),
              _buildSupportCard(),
              const SizedBox(height: 24),
              _buildLogoutButton(context),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'NovaRide v4.2.0',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 3),
    );
  }

  // ---- Page title ----
  Widget _buildHeader() {
    return const Text(
      'Profile',
      style: TextStyle(
        color: NovaColors.primaryText,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ---- Avatar, name, rider ID, edit button ----
  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: NovaColors.pink,
                child: Text(
                  'JD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: NovaColors.cyan,
                    shape: BoxShape.circle,
                    border: Border.all(color: NovaColors.card, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.black, size: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Juan dela Cruz',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Rider #NV-08567',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: NovaColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.circle, color: NovaColors.green, size: 7),
                SizedBox(width: 5),
                Text(
                  'Helmet Connected',
                  style: TextStyle(
                    color: NovaColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Trips / Distance / Safety score summary ----
  Widget _buildStatsRow() {
    return Row(
      children: const [
        Expanded(
          child: _StatCard(value: '142', label: 'TOTAL TRIPS'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(value: '1,204', label: 'KM RIDDEN', valueColor: NovaColors.cyan),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(value: '92', label: 'SAFETY SCORE', valueColor: NovaColors.green),
        ),
      ],
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

  // ---- Account settings list ----
  Widget _buildAccountCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            iconColor: NovaColors.cyan,
            title: 'Personal Information',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PersonalInformationPage()),
              );
            },
          ),
          const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
          _SettingsTile(
            icon: Icons.contact_phone_outlined,
            iconColor: NovaColors.pink,
            title: 'Emergency Contacts',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmergencyContactsPage()),
              );
            },
          ),
          const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
          _SettingsTile(
            icon: Icons.sports_motorsports_outlined,
            iconColor: NovaColors.green,
            title: 'Helmet Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelmetSettingsPage()),
              );
            },
          ),
          const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
          _SettingsTile(
            icon: Icons.notifications_none,
            iconColor: const Color(0xFFF5A623),
            title: 'Notifications',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---- Support / help settings list ----
  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: const [
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: NovaColors.cyan,
            title: 'Privacy & Security',
          ),
          Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
          _SettingsTile(
            icon: Icons.help_outline,
            iconColor: NovaColors.secondaryText,
            title: 'Help & Support',
          ),
          Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
          _SettingsTile(
            icon: Icons.info_outline,
            iconColor: NovaColors.secondaryText,
            title: 'About NovaRide',
          ),
        ],
      ),
    );
  }

  // ---- Log out button ----
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

/// One stat pill (Total Trips / KM Ridden / Safety Score).
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _StatCard({
    required this.value,
    required this.label,
    this.valueColor = NovaColors.primaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 9.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable row inside the Account / Support cards.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
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
              child: Text(
                title,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: NovaColors.secondaryText, size: 20),
          ],
        ),
      ),
    );
  }
}