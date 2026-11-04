import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novaride/app/di.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/theme/app_typography.dart';
import 'package:novaride/core/utils/initials.dart';
import 'package:novaride/core/utils/validators.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/presentation/providers/auth_state.dart';
import 'package:novaride/core/widgets/nova_buttons.dart';
import 'package:novaride/core/widgets/nova_inline_error.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_text_field.dart';

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

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

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
      await ref
          .read(authRepositoryProvider)
          .updateProfile(
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
    final colors = context.colors;
    final profile = ref.watch(authStateProvider).profile;
    _fillOnce(profile);
    final initials = initialsFrom(profile?.displayName);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const NovaScreenHeader(
              title: 'Personal information',
              subtitle: 'How NovaRide and your contacts reach you',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  kRiderGutter,
                  AppSpacing.lg,
                  kRiderGutter,
                  AppSpacing.xl,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // No camera badge: there is no photo upload yet, and
                      // a badge that does nothing when tapped is a promise.
                      Center(
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: colors.border,
                          child: initials.isEmpty
                              ? Icon(
                                  Icons.person_outline,
                                  size: 32,
                                  color: colors.textPrimary,
                                )
                              : Text(
                                  initials,
                                  style: context.text.h1.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      // The three editable fields stay in this order —
                      // name, phone, address — which is how the form's
                      // tests find them.
                      NovaTextField(
                        label: 'Full name',
                        controller: _fullNameController,
                        prefixIcon: Icons.badge_outlined,
                        validator: Validators.fullName,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _ReadOnlyField(
                        label: 'Username',
                        value: profile?.username ?? '',
                        icon: Icons.alternate_email,
                        note: 'Usernames cannot be changed.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _ReadOnlyField(
                        label: 'Email',
                        value: profile?.email ?? '',
                        icon: Icons.email_outlined,
                        note: 'Changing your email is not supported yet.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      NovaTextField(
                        label: 'Phone number',
                        controller: _phoneController,
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phoneNumber,
                        autofillHints: const [AutofillHints.telephoneNumber],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      NovaTextField(
                        label: 'Address',
                        controller: _addressController,
                        prefixIcon: Icons.location_on_outlined,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.fullStreetAddress],
                        onSubmitted: (_) {
                          if (!_isSaving) _handleSave();
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      NovaInlineError(message: _saveError),
                      NovaPrimaryButton(
                        label: 'Save changes',
                        busy: _isSaving,
                        onPressed: _handleSave,
                      ),
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
}

/// A value the rules will not let this screen change.
///
/// Shown rather than hidden: somebody wanting to know their own username
/// should not have to remember it. Sunken, with a lock and a line saying
/// why, so it reads as deliberate rather than broken — and it is not a
/// text field, so nobody types into it and loses the edit on save.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
    required this.note,
  });

  final String label;
  final String value;
  final IconData icon;
  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '$label, $value, read only. $note',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelMuted),
          const SizedBox(height: AppSpacing.xs),
          Container(
            constraints: const BoxConstraints(minHeight: AppSizes.fieldHeight),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    value,
                    style: context.text.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Icon(Icons.lock_outline, size: 18, color: colors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(note, style: context.text.caption),
        ],
      ),
    );
  }
}
