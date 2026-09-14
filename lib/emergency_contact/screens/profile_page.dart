import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import 'package:novaride/rider/screens/login_page.dart';
import '../widgets/emergency_bottom_nav_bar.dart';

/// "Profile" — the Emergency Contact's own account screen: who they are,
/// which rider they're linked to, and account/support settings, ending
/// in Log Out. Mirrors the rider-side Profile screen's structure so the
/// two modules feel consistent, just reframed around "monitoring"
/// instead of "riding."
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
              _buildLinkedRiderCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('ACCOUNT'),
              const SizedBox(height: 12),
              _buildAccountCard(),
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
      bottomNavigationBar: const EmergencyBottomNavBar(selectedIndex: 3),
    );
  }

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

  // ---- Emergency contact's own identity card ----
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
                backgroundColor: NovaColors.cyan,
                child: Text(
                  'MS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: NovaColors.pink,
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
            'Hanz',
            style: TextStyle(color: NovaColors.primaryText, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Emergency Contact',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: NovaColors.pink.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.family_restroom, color: NovaColors.pink, size: 13),
                SizedBox(width: 5),
                Text(
                  'sibling of Deor the great',
                  style: TextStyle(color: NovaColors.pink, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Which rider this account is linked to ----
  Widget _buildLinkedRiderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: NovaColors.pink,
            child: Text('JD', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoring',
                  style: TextStyle(color: NovaColors.secondaryText, fontSize: 10.5, letterSpacing: 0.4),
                ),
                SizedBox(height: 2),
                Text(
                  'Deor the great · Rider #NV-08567',
                  style: TextStyle(color: NovaColors.primaryText, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: NovaColors.secondaryText, size: 20),
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

  Widget _buildAccountCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: const [
          _SettingsTile(icon: Icons.person_outline, iconColor: NovaColors.cyan, title: 'Personal Information'),
          Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
          _SettingsTile(icon: Icons.family_restroom, iconColor: NovaColors.pink, title: 'Linked Riders'),
          Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
          _SettingsTile(icon: Icons.notifications_none, iconColor: NovaColors.amber, title: 'Notification Preferences'),
        ],
      ),
    );
  }

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
          _SettingsTile(icon: Icons.privacy_tip_outlined, iconColor: NovaColors.cyan, title: 'Privacy & Security'),
          Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
          _SettingsTile(icon: Icons.help_outline, iconColor: NovaColors.secondaryText, title: 'Help & Support'),
          Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
          _SettingsTile(icon: Icons.info_outline, iconColor: NovaColors.secondaryText, title: 'About NovaRide'),
        ],
      ),
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
              style: TextStyle(color: NovaColors.red, fontSize: 15, fontWeight: FontWeight.w700),
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
  }) : onTap = null;

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
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: NovaColors.primaryText, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, color: NovaColors.secondaryText, size: 20),
          ],
        ),
      ),
    );
  }
}