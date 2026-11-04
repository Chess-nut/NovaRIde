import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novaride/app/di.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/theme/app_typography.dart';
import 'package:novaride/core/utils/validators.dart';
import 'package:novaride/core/widgets/nova_buttons.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';
import 'package:novaride/core/widgets/nova_text_field.dart';

import '../../../../auth/presentation/providers/auth_state.dart';
import '../../../../guardian/domain/entities/guardian_link.dart';
import '../../../domain/entities/emergency_contact.dart';
import '../../providers/emergency_contacts_provider.dart';

/// "Emergency contacts" — the people a rider wants told.
///
/// Two kinds, two sections:
///
/// * **Guardians in the app.** Family members with their own NovaRide
///   guardian account. The rider makes an invite code; the guardian types
///   it within 15 minutes; from then on they see this rider's alerts,
///   live location, speed and helmet status. Either side can end it.
/// * **Phone contacts.** People without the app. Saved to
///   `riderProfiles/{uid}/emergencyContacts`, where operations can read
///   them to call these people during an incident. Nothing texts them
///   automatically, and the page says so.
///
/// The number the helmet itself texts is set on the helmet's setup page;
/// the note at the bottom points there.
class EmergencyContactsPage extends ConsumerStatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  ConsumerState<EmergencyContactsPage> createState() =>
      _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends ConsumerState<EmergencyContactsPage> {
  bool _creatingInvite = false;

  String? get _uid => ref.read(authStateProvider).profile?.uid;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------ invites

  Future<void> _createInvite() async {
    final profile = ref.read(authStateProvider).profile;
    if (profile == null || _creatingInvite) return;
    setState(() => _creatingInvite = true);
    GuardianInvite? invite;
    try {
      invite = await ref.read(guardianLinkRepositoryProvider).createInvite(
            riderUid: profile.uid,
            riderName: profile.displayName,
          );
    } on Failure catch (failure) {
      if (mounted) _toast(failure.message);
    } finally {
      // Stop the spinner before the sheet opens; otherwise it keeps
      // spinning behind the sheet until the sheet is closed.
      if (mounted) setState(() => _creatingInvite = false);
    }
    if (invite != null && mounted) await _showInvite(invite);
  }

  Future<void> _showInvite(GuardianInvite invite) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _InviteSheet(
        initial: invite,
        onNewCode: () {
          Navigator.of(context).pop();
          _createInvite();
        },
      ),
    );
  }

  // ---------------------------------------------------------- guardians

  Future<void> _removeGuardian(GuardianLink link) async {
    final name = link.guardianName.isEmpty ? 'this guardian' : link.guardianName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text(
          'They\'ll stop seeing your alerts and location. To follow you '
          'again they\'ll need a new code from you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.colors.critical,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(guardianLinkRepositoryProvider).unlink(link.guardianUid);
      if (mounted) _toast('$name removed');
    } on Failure catch (failure) {
      if (mounted) _toast(failure.message);
    }
  }

  // ----------------------------------------------------- phone contacts

  Future<void> _deleteContact(EmergencyContact contact) async {
    final uid = _uid;
    if (uid == null) return;
    final repo = ref.read(emergencyContactRepositoryProvider);
    try {
      await repo.delete(uid, contact.id);
    } on Failure catch (failure) {
      if (mounted) _toast(failure.message);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${contact.name} removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.add(uid, contact),
          ),
        ),
      );
  }

  void _openContactSheet({EmergencyContact? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _ContactSheet(existing: existing),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final guardiansAsync = ref.watch(riderGuardiansProvider);
    final invitesAsync = ref.watch(riderInvitesProvider);
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final now = ref.watch(inviteClockProvider).value ?? DateTime.now();

    final guardians = guardiansAsync.value ?? const <GuardianLink>[];
    final contacts = contactsAsync.value ?? const <EmergencyContact>[];
    final liveInvite = _newestLive(invitesAsync.value, now);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const NovaScreenHeader(
              title: 'Emergency contacts',
              subtitle: 'Who to call when something happens',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  kRiderGutter,
                  AppSpacing.lg,
                  kRiderGutter,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------------------------------------- guardians
                    const NovaSectionLabel('Guardians in the app'),
                    const SizedBox(height: AppSpacing.md),
                    if (guardiansAsync.hasError)
                      const NovaNote(
                        tone: NovaTone.critical,
                        icon: Icons.error_outline,
                        text: 'Couldn\'t load your guardians. Check your '
                            'connection and open this screen again.',
                      )
                    else if (guardians.isEmpty)
                      const NovaEmptyState(
                        icon: Icons.people_outline,
                        title: 'No guardians yet',
                        message: 'Invite a family member who has the '
                            'NovaRide guardian app.',
                      )
                    else
                      NovaListGroup(children: [
                        for (final link in guardians)
                          NovaListRow(
                            icon: Icons.person_outline,
                            title: link.guardianName.isEmpty
                                ? 'Guardian'
                                : link.guardianName,
                            subtitle: link.relationship.isEmpty
                                ? 'Sees your alerts and location'
                                : '${link.relationship} · sees your alerts '
                                    'and location',
                            trailing: IconButton(
                              tooltip: 'Remove ${link.guardianName}',
                              onPressed: () => _removeGuardian(link),
                              icon: Icon(Icons.close,
                                  color: colors.textSecondary),
                            ),
                          ),
                      ]),
                    if (liveInvite != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      NovaListGroup(children: [
                        NovaListRow(
                          icon: Icons.vpn_key_outlined,
                          title: 'Code ${formatInviteCode(liveInvite.code)}',
                          subtitle: 'Expires in '
                              '${_mmss(liveInvite.remaining(now))}',
                          onTap: () => _showInvite(liveInvite),
                        ),
                      ]),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Guardians see your alerts, live location, speed and '
                      'helmet status.',
                      style: context.text.caption,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    NovaPrimaryButton(
                      label: 'Invite a guardian',
                      icon: Icons.add,
                      busy: _creatingInvite,
                      onPressed: _createInvite,
                    ),

                    // ----------------------------------- phone contacts
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Phone contacts'),
                    const SizedBox(height: AppSpacing.md),
                    if (contactsAsync.hasError)
                      const NovaNote(
                        tone: NovaTone.critical,
                        icon: Icons.error_outline,
                        text: 'Couldn\'t load your phone contacts. Check '
                            'your connection and open this screen again.',
                      )
                    else if (contacts.isEmpty)
                      const NovaEmptyState(
                        icon: Icons.contact_phone_outlined,
                        title: 'No phone contacts',
                        message: 'Add someone who doesn\'t use the app, '
                            'like a grandparent.',
                      )
                    else
                      NovaListGroup(children: [
                        for (final contact in contacts)
                          _ContactRow(
                            contact: contact,
                            onEdit: () => _openContactSheet(existing: contact),
                            onDelete: () => _deleteContact(contact),
                          ),
                      ]),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'For people without the app. Operations can see these '
                      'and call them in an emergency. Nothing texts them '
                      'automatically.',
                      style: context.text.caption,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    NovaSecondaryButton(
                      label: 'Add phone contact',
                      icon: Icons.add,
                      onPressed: () => _openContactSheet(),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaNote(
                      text: 'The number the helmet texts by itself is set on '
                          'the helmet\'s own setup page (see Helmet settings).',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

GuardianInvite? _newestLive(List<GuardianInvite>? invites, DateTime now) {
  for (final invite in invites ?? const <GuardianInvite>[]) {
    if (!invite.isExpired(now)) return invite;
  }
  return null;
}

String _mmss(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// The code, a live countdown, Copy and Cancel.
class _InviteSheet extends ConsumerWidget {
  const _InviteSheet({required this.initial, required this.onNewCode});

  final GuardianInvite initial;
  final VoidCallback onNewCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = ref.watch(inviteClockProvider).value ?? DateTime.now();

    // Prefer the server's copy (it has the real createdAt); fall back to
    // the one just made.
    var invite = initial;
    for (final i in ref.watch(riderInvitesProvider).value ?? const <GuardianInvite>[]) {
      if (i.code == initial.code) invite = i;
    }
    final expired = invite.isExpired(now);
    final spelled = invite.code.split('').join(' ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          kRiderGutter, 0, kRiderGutter, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invite a guardian', style: context.text.h2),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Give this code to a family member. They enter it in NovaRide '
            'after signing up as a guardian.',
            style: context.text.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            label: 'Invite code $spelled',
            excludeSemantics: true,
            child: Opacity(
              opacity: expired ? 0.4 : 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < invite.code.length; i++) ...[
                    if (i == 3) const SizedBox(width: AppSpacing.md),
                    if (i != 0 && i != 3) const SizedBox(width: AppSpacing.xs),
                    Container(
                      width: 44,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceSunken,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderStrong),
                      ),
                      child: Text(invite.code[i], style: context.text.h1),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                expired ? Icons.timer_off_outlined : Icons.schedule,
                size: 18,
                color: expired ? colors.critical : colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                expired
                    ? 'This code has expired'
                    : 'Expires in ${_mmss(invite.remaining(now))}',
                style: context.text.bodyMuted.copyWith(
                  color: expired ? colors.critical : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (expired)
            NovaPrimaryButton(
              label: 'Make a new code',
              icon: Icons.refresh,
              onPressed: onNewCode,
            )
          else ...[
            NovaPrimaryButton(
              label: 'Copy code',
              icon: Icons.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invite.code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Code copied')));
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSizes.minTouchTarget,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: colors.critical),
                onPressed: () async {
                  try {
                    await ref
                        .read(guardianLinkRepositoryProvider)
                        .cancelInvite(invite.code);
                    if (context.mounted) Navigator.of(context).pop();
                  } on Failure catch (failure) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(failure.message)));
                  }
                },
                child: const Text('Cancel this code'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Add or edit one phone contact.
class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet({this.existing});

  final EmergencyContact? existing;

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _relationship =
      TextEditingController(text: widget.existing?.relationship ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final uid = ref.read(authStateProvider).profile?.uid;
    if (uid == null) return;
    final repo = ref.read(emergencyContactRepositoryProvider);
    final contact = EmergencyContact(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      relationship: _relationship.text.trim(),
      phone: _phone.text.trim(),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.existing == null) {
        await repo.add(uid, contact);
      } else {
        await repo.update(uid, contact);
      }
      if (mounted) Navigator.of(context).pop();
    } on Failure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        kRiderGutter,
        0,
        kRiderGutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isNew ? 'Add phone contact' : 'Edit contact',
                style: context.text.h2),
            const SizedBox(height: AppSpacing.xl),
            NovaTextField(
              label: 'Full name',
              controller: _name,
              prefixIcon: Icons.badge_outlined,
              autofocus: isNew,
              maxLength: 80,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter their name.' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            NovaTextField(
              label: 'Relationship',
              hint: 'e.g. Grandparent, Neighbour',
              controller: _relationship,
              prefixIcon: Icons.people_outline,
              maxLength: 40,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Say how you know them.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            NovaTextField(
              label: 'Phone number',
              controller: _phone,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              // Validators.phoneNumber treats empty as fine (it's
              // optional on a profile); here a number is the point.
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter their mobile number.'
                  : Validators.phoneNumber(v),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              NovaNote(
                tone: NovaTone.critical,
                icon: Icons.error_outline,
                text: _error!,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            NovaPrimaryButton(
              label: isNew ? 'Add contact' : 'Save changes',
              busy: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// One phone contact: who, how they're related, their number, edit and
/// delete.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return NovaListRow(
      icon: Icons.phone_outlined,
      title: contact.name,
      subtitle: '${contact.relationship} · ${contact.phone}',
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit ${contact.name}',
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, color: colors.textSecondary),
          ),
          IconButton(
            tooltip: 'Remove ${contact.name}',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: colors.critical),
          ),
        ],
      ),
    );
  }
}
