import 'package:flutter/material.dart';
import 'package:novaride/family/models/family_models.dart';
import 'package:novaride/family/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class FamilyProfilePage extends StatelessWidget {
  const FamilyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = const FamilyUserProfile(
      name: 'Maria Santos',
      relationship: 'Mother',
      phoneNumber: '+63 912 345 6789',
      email: 'maria.santos@email.com',
      connectedRider: 'Juan dela Cruz',
    );

    final permissionItems = const [
      FamilyPermission(type: FamilyPermissionType.liveLocation, label: 'Live Location', enabled: true),
      FamilyPermission(type: FamilyPermissionType.emergencyAlerts, label: 'Emergency Alerts', enabled: true),
      FamilyPermission(type: FamilyPermissionType.tripStatus, label: 'Trip Status', enabled: true),
      FamilyPermission(type: FamilyPermissionType.helmetStatus, label: 'Helmet Status', enabled: true),
      FamilyPermission(type: FamilyPermissionType.incidentHistory, label: 'Incident History', enabled: true),
    ];

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: NovaColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: NovaColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: NovaColors.pink,
                      child: Text('MS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.name,
                      style: const TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.relationship,
                      style: const TextStyle(
                        color: NovaColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle('Connected Riders'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NovaColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: NovaColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: NovaColors.green,
                      child: Text('JD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.connectedRider,
                        style: const TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.circle, color: NovaColors.green, size: 8),
                    const SizedBox(width: 6),
                    const Text(
                      'Connected',
                      style: TextStyle(
                        color: NovaColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle('Notification Settings'),
              const SizedBox(height: 12),
              _buildToggleList(const [
                'Emergency Alerts',
                'Accident Detection',
                'Trip Started',
                'Rider Offline',
                'GPS Signal Lost',
              ]),
              const SizedBox(height: 24),
              _SectionTitle('Privacy'),
              const SizedBox(height: 12),
              _SettingsListTile(title: 'Manage Rider Permissions', onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: NovaColors.card,
                    title: const Text('Permissions', style: TextStyle(color: Colors.white)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: permissionItems.map((permission) => CheckboxListTile(
                        value: permission.enabled,
                        activeColor: NovaColors.cyan,
                        checkColor: Colors.black,
                        title: Text(permission.label, style: const TextStyle(color: Colors.white)),
                        onChanged: (_) {},
                      )).toList(),
                    ),
                  ),
                );
              }),
              _SettingsListTile(title: 'Remove Rider Connection', onTap: () {}),
              const SizedBox(height: 24),
              _SectionTitle('Account'),
              const SizedBox(height: 12),
              _SettingsListTile(title: 'Logout', onTap: () {}, icon: Icons.logout, color: NovaColors.red),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FamilyBottomNavBar(selectedIndex: 4),
    );
  }

  Widget _buildToggleList(List<String> items) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Checkbox(
                value: true,
                activeColor: NovaColors.cyan,
                onChanged: (_) {},
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
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
}

class _SettingsListTile extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;

  const _SettingsListTile({required this.title, this.icon, this.color = NovaColors.cyan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        leading: Icon(icon ?? Icons.settings_outlined, color: color, size: 20),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: NovaColors.secondaryText),
        onTap: onTap,
      ),
    );
  }
}
