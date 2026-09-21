import 'package:flutter/material.dart';
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
              CircleAvatar(
                radius: 38,
                backgroundColor: NovaColors.pink,
                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null
                    ? const Text(
                        'DT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
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