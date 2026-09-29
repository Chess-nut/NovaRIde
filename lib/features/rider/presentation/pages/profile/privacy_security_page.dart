import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import '../legal_document_page.dart';

/// "Privacy & Security" screen — data controls and account security.
///
/// The toggles below are local UI state only for now (no backend calls
/// yet, per plan — this screen just needs to exist and look right first).
/// "Change Password" and "Delete Account" show a snackbar placeholder
/// until the auth backend is wired up.
class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool _biometricLock = false;
  bool _shareRideDataForSafety = true;

  void _notImplemented(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: NovaColors.card,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '$feature will be available once account backend is connected',
          style: const TextStyle(color: NovaColors.primaryText),
        ),
      ),
    );
  }

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
                    _buildSectionTitle('SECURITY'),
                    const SizedBox(height: 12),
                    _buildCard([
                      _ActionRow(
                        icon: Icons.lock_outline,
                        iconColor: NovaColors.cyan,
                        title: 'Change Password',
                        subtitle: 'Update your account password',
                        onTap: () => _notImplemented('Password changes'),
                      ),
                      _divider(),
                      _ToggleRow(
                        icon: Icons.fingerprint,
                        iconColor: NovaColors.green,
                        title: 'Biometric Lock',
                        subtitle: 'Require Face/Fingerprint ID to open NovaRide',
                        value: _biometricLock,
                        onChanged: (v) => setState(() => _biometricLock = v),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('PRIVACY'),
                    const SizedBox(height: 12),
                    _buildCard([
                      _ToggleRow(
                        icon: Icons.share_location_outlined,
                        iconColor: NovaColors.pink,
                        title: 'Location Sharing on SOS',
                        subtitle: 'Always on — required for emergency response',
                        value: true,
                        onChanged: null,
                      ),
                      _divider(),
                      _ToggleRow(
                        icon: Icons.insights_outlined,
                        iconColor: NovaColors.purple,
                        title: 'Share Ride Data for Safety Research',
                        subtitle: 'Helps improve crash-detection accuracy',
                        value: _shareRideDataForSafety,
                        onChanged: (v) => setState(() => _shareRideDataForSafety = v),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('LEGAL'),
                    const SizedBox(height: 12),
                    _buildCard([
                      _ActionRow(
                        icon: Icons.description_outlined,
                        iconColor: NovaColors.cyan,
                        title: 'View Privacy Policy',
                        subtitle: 'What we collect and how it\'s used',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LegalDocumentPage(document: LegalDocument.privacy),
                            ),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('DANGER ZONE'),
                    const SizedBox(height: 12),
                    _buildCard([
                      _ActionRow(
                        icon: Icons.delete_outline,
                        iconColor: NovaColors.red,
                        title: 'Delete Account',
                        subtitle: 'Permanently remove your data',
                        titleColor: NovaColors.red,
                        onTap: () => _notImplemented('Account deletion'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: NovaColors.cardBorder, indent: 56);

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
                'Account Settings',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Password, privacy, and data controls',
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

  Widget _buildCard(List<Widget> children) {
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

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: NovaColors.cyan,
            activeTrackColor: NovaColors.cyan.withValues(alpha: 0.3),
            inactiveThumbColor: NovaColors.secondaryText,
            inactiveTrackColor: NovaColors.cardBorder,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
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
                    style: TextStyle(
                      color: titleColor ?? NovaColors.primaryText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
                  ),
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