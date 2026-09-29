import 'package:flutter/material.dart';
<<<<<<< HEAD:lib/features/rider/presentation/pages/profile_page.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/core/utils/initials.dart';
import 'package:novaride/core/widgets/unavailable.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';

import 'package:novaride/app/di.dart';
import 'package:novaride/shared/theme.dart';

import '../widgets/nova_bottom_nav_bar.dart';
import 'profile/emergency_contacts_page.dart';
import 'profile/helmet_settings_page.dart';
import 'profile/notifications_page.dart';
import 'profile/personal_information.dart';

/// "Profile" screen — rider info, quick stats, account settings, and
/// logout. Opened from the bottom nav bar's PROFILE tab.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
=======
import 'package:image_picker/image_picker.dart';
import 'package:novaride/shared/theme.dart';
import '../data/avatar_upload_service.dart';
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
///
/// Now a [StatefulWidget] (it wasn't before) because the avatar photo has
/// to live somewhere: [_avatarUrl] holds the uploaded photo's download URL
/// once the rider picks one, and [_isUploadingAvatar] drives the little
/// spinner while that upload is in flight.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // There's no rider login/session yet, so there's no real signed-in rider
  // ID to key the upload on — see AvatarUploadService's doc comment. Every
  // rider on a test build currently shares this one demo ID.
  static const _riderId = 'NV-08567';

  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
>>>>>>> origin/main:lib/rider/screens/profile_page.dart
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
<<<<<<< HEAD:lib/features/rider/presentation/pages/profile_page.dart
              _buildProfileCard(ref.watch(authStateProvider).profile),
=======
              _buildProfileCard(context),
>>>>>>> origin/main:lib/rider/screens/profile_page.dart
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
                  onTap: () => _push(context, const RideHailingOperatorPage()),
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
      bottomNavigationBar: const NovaBottomNavBar(selectedIndex: 2),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // ---- Avatar picking ----

  /// Bottom sheet with the two sources — this is the "gallery or camera"
  /// choice, shown when the rider taps the little camera badge on their
  /// avatar. Neither option is functional until Cloudinary is configured
  /// in [AvatarUploadService].
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NovaColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Update profile photo',
                    style: TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: NovaColors.cyan),
                title: const Text('Take Photo', style: TextStyle(color: NovaColors.primaryText)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickAndUpload(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: NovaColors.cyan),
                title: const Text('Choose from Gallery', style: TextStyle(color: NovaColors.primaryText)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() => _isUploadingAvatar = true);
    try {
      final url = await AvatarUploadService.pickAndUpload(source: source, riderId: _riderId);
      if (!mounted) return;
      if (url != null) {
        setState(() => _avatarUrl = url);
        _showSnack('Profile photo updated.');
      }
      // url == null just means the rider backed out of the picker — no
      // error, nothing to show.
    } on AvatarUploadException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: NovaColors.card,
        behavior: SnackBarBehavior.floating,
        content: Text(message, style: const TextStyle(color: NovaColors.primaryText)),
      ),
    );
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
          onTap: () => _push(context, const SettingsPage()),
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
<<<<<<< HEAD:lib/features/rider/presentation/pages/profile_page.dart
  Widget _buildProfileCard(UserProfile? profile) {
=======
  Widget _buildProfileCard(BuildContext context) {
>>>>>>> origin/main:lib/rider/screens/profile_page.dart
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
              CircleAvatar(
                radius: 38,
                backgroundColor: NovaColors.pink,
<<<<<<< HEAD:lib/features/rider/presentation/pages/profile_page.dart
                child: initialsFrom(profile?.displayName).isEmpty
                    ? const Icon(Icons.person_outline,
                        color: Colors.white, size: 32)
                    : Text(
                        initialsFrom(profile?.displayName),
                        style: const TextStyle(
=======
                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null
                    ? const Text(
                        'DT',
                        style: TextStyle(
>>>>>>> origin/main:lib/rider/screens/profile_page.dart
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
<<<<<<< HEAD:lib/features/rider/presentation/pages/profile_page.dart
                      ),
              ),
=======
                      )
                    : null,
              ),
              if (_isUploadingAvatar)
                const Positioned.fill(
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.black54,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    ),
                  ),
                ),
>>>>>>> origin/main:lib/rider/screens/profile_page.dart
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _isUploadingAvatar ? null : _showAvatarPicker,
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
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            profile?.displayName ?? 'Loading…',
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          // Was 'Rider #NV-08567'. A rider number belongs to the console's
          // roster (riders/{R-001}); a mobile account cannot read that
          // collection and nothing links the two yet, so there is no
          // number to show. The username is real and is what they signed
          // in with.
          Text(
            profile == null ? '' : '@${profile.username}',
            style: const TextStyle(color: NovaColors.secondaryText, fontSize: 13),
          ),
<<<<<<< HEAD:lib/features/rider/presentation/pages/profile_page.dart
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: NovaColors.secondaryText.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.circle, color: NovaColors.secondaryText, size: 7),
                SizedBox(width: 5),
                Text(
                  'No helmet paired',
                  style: TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
=======
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
                onTap: () => _push(context, const PersonalInformationPage()),
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
>>>>>>> origin/main:lib/rider/screens/profile_page.dart
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
  //
  // 142 trips, 1,204 km and a safety score of 92 were invented. None of
  // the three is computed anywhere: there is no trips collection, no
  // helmet feed to build one from, and no scoring rule. Em dashes until
  // something measures them.
  Widget _buildStatsRow() {
    return Row(
      children: const [
        Expanded(
          child: _StatCard(value: Unavailable.dash, label: 'TOTAL TRIPS'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
              value: Unavailable.dash,
              label: 'KM RIDDEN',
              valueColor: NovaColors.secondaryText),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
              value: Unavailable.dash,
              label: 'SAFETY SCORE',
              valueColor: NovaColors.secondaryText),
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
<<<<<<< HEAD:lib/features/rider/presentation/pages/profile_page.dart
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
          // Signing out of Firebase is what signs out: the auth stream
          // fires, authStateProvider goes to signed-out and the router's
          // gate takes it from there. A Navigator push instead would
          // leave a live session behind a login screen. Wrapped in a
          // Consumer rather than making the whole page a ConsumerWidget —
          // the rider screens are Phase 7's to restructure.
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(authRepositoryProvider).signOut();
              },
              child: const Text('Log Out', style: TextStyle(color: NovaColors.red)),
            ),
          ),
        ],
      ),
=======
      child: Column(children: children),
>>>>>>> origin/main:lib/rider/screens/profile_page.dart
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
<<<<<<< HEAD:lib/features/rider/presentation/pages/profile_page.dart
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
=======
}
>>>>>>> origin/main:lib/rider/screens/profile_page.dart
