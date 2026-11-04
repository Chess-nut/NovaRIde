import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/app/di.dart';
import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/theme/app_typography.dart';
import 'package:novaride/core/utils/initials.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/presentation/pages/legal_document_page.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';

import '../widgets/nova_bottom_nav_bar.dart';
import 'profile/emergency_contacts_page.dart';
import 'profile/helmet_settings_page.dart';
import 'profile/notifications_page.dart';
import 'profile/personal_information.dart';

/// "Profile" — who is signed in, their settings, and the way out.
///
/// On Signal since the Home redesign. Two things are gone rather than
/// restyled:
///
/// - **The trips / km / safety score tiles.** None of the three is
///   computed anywhere — no trips collection, no scoring rule — so they
///   could only ever show dashes. Home dropped its never-filled tiles for
///   the same reason.
/// - **"Help & support" and the version line.** The row went nowhere
///   when tapped, and "v4.2.0" was not the app's version. Privacy now
///   opens the real policy page, and About opens Flutter's about box.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(authStateProvider).profile;

    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NovaScreenHeader(title: 'Profile', showBack: false),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kRiderGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    _IdentityCard(profile: profile),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Account'),
                    const SizedBox(height: AppSpacing.md),
                    NovaListGroup(
                      children: [
                        NovaListRow(
                          icon: Icons.badge_outlined,
                          title: 'Personal information',
                          subtitle: 'Name, phone and address',
                          onTap: () => open(const PersonalInformationPage()),
                        ),
                        NovaListRow(
                          icon: Icons.contact_phone_outlined,
                          title: 'Emergency contacts',
                          subtitle: 'Who to call when something happens',
                          onTap: () => open(const EmergencyContactsPage()),
                        ),
                        NovaListRow(
                          icon: Icons.sports_motorsports_outlined,
                          title: 'Helmet settings',
                          subtitle: 'Status and how to change its settings',
                          onTap: () => open(const HelmetSettingsPage()),
                        ),
                        NovaListRow(
                          icon: Icons.notifications_none,
                          title: 'Notifications',
                          subtitle: 'What NovaRide tells you about',
                          onTap: () => open(const NotificationsPage()),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('About'),
                    const SizedBox(height: AppSpacing.md),
                    NovaListGroup(
                      children: [
                        NovaListRow(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy policy',
                          onTap: () => open(
                            const LegalDocumentPage(
                              document: LegalDocument.privacy,
                            ),
                          ),
                        ),
                        NovaListRow(
                          icon: Icons.description_outlined,
                          title: 'Terms of service',
                          onTap: () => open(
                            const LegalDocumentPage(
                              document: LegalDocument.terms,
                            ),
                          ),
                        ),
                        NovaListRow(
                          icon: Icons.info_outline,
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
                    const SizedBox(height: AppSpacing.xxl),
                    NovaDestructiveButton(
                      label: 'Log out',
                      icon: Icons.logout,
                      onPressed: () => _confirmLogout(context),
                    ),
                  ],
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
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surfaceRaised,
        title: Text('Log out?', style: dialogContext.text.h2),
        content: Text(
          'You will need your username or email and password to sign back in.',
          style: dialogContext.text.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          // Signing out of Firebase is what signs out: the auth stream
          // fires, authStateProvider goes to signed-out and the router's
          // gate takes it from there. A Navigator push instead would
          // leave a live session behind a login screen.
          Consumer(
            builder: (context, ref, _) => TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.critical),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(authRepositoryProvider).signOut();
              },
              child: const Text('Log out'),
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
    final colors = context.colors;
    final initials = initialsFrom(profile?.displayName);

    return NovaCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          // Neutral, not pink: colour means status, and an avatar has none.
          CircleAvatar(
            radius: 32,
            backgroundColor: colors.border,
            child: initials.isEmpty
                ? Icon(
                    Icons.person_outline,
                    size: 28,
                    color: colors.textPrimary,
                  )
                : Text(
                    initials,
                    style: context.text.h2.copyWith(color: colors.textPrimary),
                  ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.displayName ?? 'Loading…',
                  style: context.text.h2,
                ),
                if (profile != null) ...[
                  const SizedBox(height: 2),
                  // Was 'Rider #NV-08567'. A rider number belongs to the
                  // console's roster, which a mobile account cannot read;
                  // the username is real and is what they signed in with.
                  Text('@${profile!.username}', style: context.text.bodyMuted),
                ],
                const SizedBox(height: AppSpacing.sm),
                // Nothing links an account to a helmet yet
                // (riders/{id}.authUid is unwritten), so none is paired —
                // whatever helmet Home happens to be watching.
                const NovaPill(
                  label: 'No helmet paired',
                  tone: NovaTone.offline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
