import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/initials.dart';
import '../../../../core/widgets/nova_lists.dart';
import '../../../../core/widgets/nova_surfaces.dart';
import '../../../auth/presentation/pages/legal_document_page.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../rider/presentation/pages/profile/personal_information.dart';
import '../../domain/entities/guardian_link.dart';
import '../providers/guardian_providers.dart';
import '../widgets/guardian_common.dart';

/// The guardian's Profile: who they are, the rider they follow (and how
/// to stop), their details, the legal pages, and Log out.
class GuardianProfilePage extends ConsumerWidget {
  const GuardianProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(authStateProvider).profile;
    final link = ref.watch(myGuardianLinkProvider).value;
    final account = ref.watch(followedRiderAccountProvider).value;

    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    final name = profile?.displayName ?? '';
    final initials = initialsFrom(profile?.displayName);

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
                    const SizedBox(height: AppSpacing.lg),
                    NovaCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: colors.border,
                            child: initials.isEmpty
                                ? Icon(Icons.person_outline,
                                    color: colors.textPrimary)
                                : Text(initials,
                                    style: context.text.h2
                                        .copyWith(color: colors.textPrimary)),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.isEmpty ? 'Loading…' : name,
                                    style: context.text.h2),
                                if (profile != null)
                                  Text('@${profile.username} · Guardian',
                                      style: context.text.bodyMuted),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Rider you follow'),
                    const SizedBox(height: AppSpacing.md),
                    if (link == null)
                      const NovaListGroup(children: [
                        NovaListRow(
                          icon: Icons.link_off,
                          title: 'Not following anyone',
                          subtitle: 'Enter a rider\'s invite code on Home',
                        ),
                      ])
                    else
                      NovaListGroup(children: [
                        NovaListRow(
                          icon: Icons.sports_motorsports_outlined,
                          title: account?.displayName ?? 'Your rider',
                          subtitle: _linkedSince(link),
                        ),
                        NovaListRow(
                          icon: Icons.link_off,
                          title: 'Unlink from ${account?.firstName ?? 'this rider'}',
                          subtitle: 'You\'ll stop seeing their alerts and location',
                          tone: NovaTone.critical,
                          onTap: () => _confirmUnlink(
                              context, link, account?.firstName ?? 'this rider'),
                          trailing: const SizedBox.shrink(),
                        ),
                      ]),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Account'),
                    const SizedBox(height: AppSpacing.md),
                    NovaListGroup(children: [
                      NovaListRow(
                        icon: Icons.badge_outlined,
                        title: 'Personal information',
                        subtitle: 'Name, phone and address',
                        onTap: () => open(const PersonalInformationPage()),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('About'),
                    const SizedBox(height: AppSpacing.md),
                    NovaListGroup(children: [
                      NovaListRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy policy',
                        onTap: () => open(
                          const LegalDocumentPage(document: LegalDocument.privacy),
                        ),
                      ),
                      NovaListRow(
                        icon: Icons.description_outlined,
                        title: 'Terms of service',
                        onTap: () => open(
                          const LegalDocumentPage(document: LegalDocument.terms),
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
                    ]),
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
      bottomNavigationBar: const GuardianBottomNavBar(selectedIndex: 3),
    );
  }

  static String _linkedSince(GuardianLink link) {
    final rel = link.relationship.isEmpty ? 'Linked' : 'Your ${link.relationship.toLowerCase()}';
    final at = link.createdAt;
    if (at == null) return rel;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec'];
    final local = at.toLocal();
    return '$rel · linked since ${months[local.month - 1]} ${local.day}';
  }

  void _confirmUnlink(BuildContext context, GuardianLink link, String firstName) {
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surfaceRaised,
        title: Text('Unlink from $firstName?', style: dialogContext.text.h2),
        content: Text(
          'You\'ll stop seeing their alerts and location. To follow them '
          'again you\'ll need a new code from them.',
          style: dialogContext.text.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          Consumer(
            builder: (_, ref, _) => TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.critical),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await ref
                      .read(guardianLinkRepositoryProvider)
                      .unlink(link.guardianUid);
                } on Failure catch (failure) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(failure.message)));
                }
              },
              child: const Text('Unlink'),
            ),
          ),
        ],
      ),
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
          Consumer(
            builder: (_, ref, _) => TextButton(
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
