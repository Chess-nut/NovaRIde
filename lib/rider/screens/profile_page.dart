import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../widgets/nova_bottom_nav_bar.dart';
import '../widgets/nova_settings_tile.dart';
import 'settings_page.dart';
import 'profile/personal_information.dart';
import 'profile/emergency_contacts_page.dart';
import 'profile/helmet_settings_page.dart';
import 'profile/ride_hailing_operator_page.dart';

/// "Profile" screen — who the rider is, plus the account/device content
/// the capstone system design assigns to this module: personal details,
/// emergency contacts, helmet device settings, and ride-hailing operator.
///
/// [SettingsPage] (reached via the gear icon) holds app-level preferences
/// instead — notifications, account security, help/support, and legal —
/// per the same system design.
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
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildProfileCard(context),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildSectionTitle('YOUR DETAILS'),
              const SizedBox(height: 12),
              _buildCard(context, [
                NovaSettingsTile(
                  icon: Icons.person_outline,
                  iconColor: NovaColors.cyan,
                  title: 'Personal Information',
                  subtitle: 'Name, email, phone, address',
                  onTap: () => _push(context, const PersonalInformationPage()),
                ),
                novaTileDivider(),
                NovaSettingsTile(
                  icon: Icons.contact_phone_outlined,
                  iconColor: NovaColors.pink,
                  title: 'Emergency Contacts',
                  subtitle: 'Who gets notified on SOS',
                  onTap: () => _push(context, const EmergencyContactsPage()),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('DEVICE'),
              const SizedBox(height: 12),
              _buildCard(context, [
                NovaSettingsTile(
                  icon: Icons.sports_motorsports_outlined,
                  iconColor: NovaColors.green,
                  title: 'Helmet Settings',
                  subtitle: 'Pairing, connection, detection',
                  onTap: () => _push(context, const HelmetSettingsPage()),
                ),
                novaTileDivider(),
                NovaSettingsTile(
                  icon: Icons.two_wheeler,
                  iconColor: const Color(0xFFF5A623),
                  title: 'Ride-Hailing Operator',
                  subtitle: 'Angkas',
                  onTap: () => _push(context, RideHailingOperatorPage()),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('SETTINGS'),
              const SizedBox(height: 12),
              _buildCard(context, [
                NovaSettingsTile(
                  icon: Icons.settings_outlined,
                  iconColor: NovaColors.secondaryText,
                  title: 'Settings',
                  subtitle: 'Notifications, account, help & support',
                  onTap: () => _push(context, const SettingsPage()),
                ),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 3),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // ---- Page title + settings entry point ----
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            color: NovaColors.primaryText,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: NovaColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: NovaColors.cardBorder),
            ),
            child: const Icon(Icons.settings_outlined, color: NovaColors.secondaryText, size: 19),
          ),
        ),
      ],
    );
  }

  // ---- Avatar, name, rider ID, edit button ----
  Widget _buildProfileCard(BuildContext context) {
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
                  'DT',
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
            'Deor the great',
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
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PersonalInformationPage()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: NovaColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, color: NovaColors.cyan, size: 12),
                      SizedBox(width: 5),
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: NovaColors.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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