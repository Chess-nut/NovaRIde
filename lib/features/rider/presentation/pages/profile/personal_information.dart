import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novaride/app/di.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/core/utils/initials.dart';
import 'package:novaride/core/utils/validators.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/shared/theme.dart';

/// "Personal Information" — view and edit the account record.
///
/// Reads and writes `users/{uid}`, the same document `ensureProfile`
/// creates. It used to be pre-filled with the demo persona and its Save
/// button waited 600ms and showed a snackbar.
///
/// **Email and username are shown but not editable.** The security rules
/// make both immutable — an email change belongs to Firebase Auth, and a
/// username is claimed under `usernames/`, where nothing can be
/// transferred. A form that let someone type into them would fail on
/// save with a permission error and no way to understand why, so it says
/// so on the field instead.
class PersonalInformationPage extends ConsumerStatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  ConsumerState<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState
    extends ConsumerState<PersonalInformationPage> {
  final _formKey = GlobalKey<FormState>();

<<<<<<< HEAD:lib/features/rider/presentation/pages/profile/personal_information.dart
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
=======
  // Pre-filled with the same mock rider used across the app.
  final _fullNameController = TextEditingController(text: 'Deor the great');
  final _usernameController = TextEditingController(text: 'deor.thegreat');
  final _emailController = TextEditingController(text: 'deor.thegreat@email.com');
  final _phoneController = TextEditingController(text: '+63 917 123 4567');
  final _addressController = TextEditingController(text: 'Makati City, Metro Manila');
>>>>>>> origin/main:lib/rider/screens/profile/personal_information.dart

  bool _isSaving = false;
  String? _saveError;

  /// The profile the fields were filled from, so an edit is not thrown
  /// away when the auth stream re-emits mid-typing.
  String? _loadedForUid;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Fills the fields once per account, not on every rebuild.
  void _fillOnce(UserProfile? profile) {
    if (profile == null || _loadedForUid == profile.uid) return;
    _loadedForUid = profile.uid;
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phoneNumber ?? '';
    _addressController.text = profile.address ?? '';
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      await ref.read(authRepositoryProvider).updateProfile(
            fullName: _fullNameController.text,
            phoneNumber: _phoneController.text,
            address: _addressController.text,
          );
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal information updated')),
      );
      Navigator.of(context).pop();
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = failure.message;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).profile;
    _fillOnce(profile);

    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      _buildAvatar(profile),
                      const SizedBox(height: 28),
                      _buildLabel('FULL NAME'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _fullNameController,
                        icon: Icons.badge_outlined,
                        validator: Validators.fullName,
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('USERNAME'),
                      const SizedBox(height: 8),
                      _buildReadOnlyField(
                        value: profile?.username ?? '',
                        icon: Icons.person_outline,
                        note: 'Usernames cannot be changed.',
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('EMAIL'),
                      const SizedBox(height: 8),
                      _buildReadOnlyField(
                        value: profile?.email ?? '',
                        icon: Icons.email_outlined,
                        note: 'Changing your email is not supported yet.',
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('PHONE NUMBER'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _phoneController,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phoneNumber,
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('ADDRESS'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _addressController,
                        icon: Icons.location_on_outlined,
                        validator: (_) => null,
                      ),
                      const SizedBox(height: 22),
                      if (_saveError != null) ...[
                        Text(
                          _saveError!,
                          style: const TextStyle(
                              color: NovaColors.red, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                'Personal Information',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage your personal details',
                style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserProfile? profile) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: NovaColors.pink,
<<<<<<< HEAD:lib/features/rider/presentation/pages/profile/personal_information.dart
            child: initialsFrom(profile?.displayName).isEmpty
                ? const Icon(Icons.person_outline,
                    color: Colors.white, size: 34)
                : Text(
                    initialsFrom(profile?.displayName),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 26),
                  ),
=======
            child: Text(
              'DT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26),
            ),
>>>>>>> origin/main:lib/rider/screens/profile/personal_information.dart
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: NovaColors.cyan,
                shape: BoxShape.circle,
                border: Border.all(color: NovaColors.background, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.black, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: NovaColors.secondaryText,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  /// A value the rules will not let this screen change.
  ///
  /// Shown rather than hidden: somebody wanting to know their own
  /// username should not have to remember it. Dimmed, with a lock and a
  /// line saying why, so it reads as deliberate rather than broken —
  /// and so nobody types into it and loses the edit on save.
  Widget _buildReadOnlyField({
    required String value,
    required IconData icon,
    required String note,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: NovaColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NovaColors.cardBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: NovaColors.secondaryText, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                      color: NovaColors.secondaryText, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.lock_outline,
                  color: NovaColors.secondaryText, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          note,
          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: NovaColors.primaryText, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: NovaColors.secondaryText, size: 20),
        filled: true,
        fillColor: NovaColors.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: border(NovaColors.cardBorder),
        enabledBorder: border(NovaColors.cardBorder),
        focusedBorder: border(NovaColors.cyan),
        errorBorder: border(NovaColors.red),
        focusedErrorBorder: border(NovaColors.red),
        errorStyle: const TextStyle(color: NovaColors.red, fontSize: 11),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: NovaColors.cyan,
          disabledBackgroundColor: NovaColors.cyan.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Text(
                'SAVE CHANGES',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}
