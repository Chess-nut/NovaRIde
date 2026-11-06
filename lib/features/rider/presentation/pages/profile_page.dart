import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/app/di.dart';
import 'package:novaride/core/utils/initials.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/presentation/pages/legal_document_page.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/shared/theme.dart';

import '../widgets/nova_bottom_nav_bar.dart';
import '../widgets/nova_classic.dart';
import 'profile/emergency_contacts_page.dart';
import 'profile/helmet_settings_page.dart';
import 'profile/notifications_page.dart';
import 'profile/personal_information.dart';

/// "Profile" — who is signed in, their settings, and the way out.
///
/// The original NovaRide look (icon-circle rows in dark cards, ACCOUNT /
/// ABOUT captions, the outlined red Log Out), with the newer identity card
/// on top: avatar beside name, username and helmet status.
///
/// Gone rather than restyled:
///
/// - **The trips / km / safety score tiles.** None of the three is
///   computed anywhere, so they could only ever show dashes.
/// - **"Help & Support" and "NovaRide v4.2.0".** The row went nowhere, and
///   v4.2.0 was not the app's version. Privacy opens the real policy and
///   About opens Flutter's about box.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).profile;

    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Profile',
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _IdentityCard(profile: profile),
              const SizedBox(height: 24),
              const ClassicCapsLabel('ACCOUNT'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline,
                    iconColor: NovaColors.cyan,
                    title: 'Personal information',
                    onTap: () => open(const PersonalInformationPage()),
                  ),
                  _SettingsTile(
                    icon: Icons.contact_phone_outlined,
                    iconColor: NovaColors.pink,
                    title: 'Emergency contacts',
                    onTap: () => open(const EmergencyContactsPage()),
                  ),
                  _SettingsTile(
                    icon: Icons.sports_motorsports_outlined,
                    iconColor: NovaColors.green,
                    title: 'Helmet settings',
                    onTap: () => open(const HelmetSettingsPage()),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_none,
                    iconColor: NovaColors.amber,
                    title: 'Notifications',
                    onTap: () => open(const NotificationsPage()),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ClassicCapsLabel('ABOUT'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: NovaColors.cyan,
                    title: 'Privacy policy',
                    onTap: () => open(
                      const LegalDocumentPage(document: LegalDocument.privacy),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    iconColor: NovaColors.purple,
                    title: 'Terms of service',
                    onTap: () => open(
                      const LegalDocumentPage(document: LegalDocument.terms),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    iconColor: NovaColors.secondaryText,
                    title: 'About NovaRide',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'NovaRide',
                      applicationLegalese:
                          'IoT smart helmet for accident detection and '
                          'emergency response.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NovaColors.red,
                    side: const BorderSide(color: NovaColors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    'Log out',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 3),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NovaColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log out?',
          style: TextStyle(
            color: NovaColors.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'You will need your username or email and password to sign back in.',
          style: TextStyle(color: NovaColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: NovaColors.secondaryText),
            ),
          ),
          // Signing out of Firebase is what signs out: the auth stream
          // fires, authStateProvider goes to signed-out and the router's
          // gate takes it from there.
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(authRepositoryProvider).signOut();
              },
              child: const Text(
                'Log out',
                style: TextStyle(color: NovaColors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar, name, username, and whether a helmet is linked to the account.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final initials = initialsFrom(profile?.displayName);

    return ClassicCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Neutral, not pink: colour means status, and an avatar has none.
          CircleAvatar(
            radius: 32,
            backgroundColor: NovaColors.cardBorder,
            child: initials.isEmpty
                ? const Icon(
                    Icons.person_outline,
                    size: 28,
                    color: NovaColors.primaryText,
                  )
                : Text(
                    initials,
                    style: const TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.displayName ?? 'Loading…',
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (profile != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${profile!.username}',
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Nothing links an account to a helmet from the app yet,
                // so none is paired — whatever helmet Home is watching.
                const ClassicPill(
                  label: 'No helmet paired',
                  color: NovaColors.secondaryText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A dark card of settings rows with hairlines between them.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClassicCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                color: NovaColors.cardBorder,
                indent: 56,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClassicIconCircle(icon: icon, color: iconColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: NovaColors.secondaryText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
