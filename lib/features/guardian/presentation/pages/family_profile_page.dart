import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:novaride/core/constants/app_routes.dart';
import 'package:novaride/features/guardian/data/family_repository.dart';
import 'package:novaride/features/guardian/domain/models/family_models.dart';
import 'package:novaride/features/guardian/presentation/widgets/family_bottom_nav_bar.dart';
import 'package:novaride/shared/theme.dart';

class FamilyProfilePage extends ConsumerStatefulWidget {
  const FamilyProfilePage({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  ConsumerState<FamilyProfilePage> createState() => _FamilyProfilePageState();
}

class _FamilyProfilePageState extends ConsumerState<FamilyProfilePage> {
  late final FamilyRepository _repository =
      widget.repository ?? ref.read(familyRepositoryProvider);
  bool _actionInProgress = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _createInvite() async {
    try {
      final code = await _repository.createInvite();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: NovaColors.card,
          title: const Text(
            'Family invite code',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this one-use code with your guardian. It expires in 24 hours.',
                style: TextStyle(color: NovaColors.secondaryText),
              ),
              const SizedBox(height: 14),
              SelectableText(
                code,
                style: const TextStyle(
                  color: NovaColors.cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Copy code'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NovaColors.card,
        title: const Text('Leave family?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will lose access to this rider’s shared data.',
          style: TextStyle(color: NovaColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(_repository.leaveFamily);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: NovaColors.background,
    body: SafeArea(
      child: StreamBuilder<FamilyUserProfile>(
        stream: _repository.watchUserProfile(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.hasError) {
            return _Message(
              title: 'Profile unavailable',
              message: profileSnapshot.error.toString(),
            );
          }
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: NovaColors.cyan),
            );
          }
          final profile = profileSnapshot.data;
          if (profile == null) {
            return const _Message(
              title: 'Profile unavailable',
              message: 'Your account profile could not be loaded.',
            );
          }
          return StreamBuilder<List<FamilyMember>>(
            stream: _repository.watchFamilyMembers(),
            builder: (context, memberSnapshot) {
              if (memberSnapshot.hasError) {
                return _Message(
                  title: 'Family information unavailable',
                  message: memberSnapshot.error.toString(),
                );
              }
              if (memberSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: NovaColors.cyan),
                );
              }
              return _ProfileContent(
                profile: profile,
                members: memberSnapshot.data ?? const [],
                repository: _repository,
                actionInProgress: _actionInProgress,
                onInvite: _createInvite,
                onLeave: _confirmLeave,
                onLogout: () => _run(_repository.signOut),
                onNotificationChanged: (key, enabled) => _run(
                  () => _repository.setNotificationSetting(key, enabled),
                ),
                onPermissionChanged: (memberUid, permission, enabled) =>
                    _run(
                      () => _repository.setMemberPermission(
                        memberUid,
                        permission,
                        enabled,
                      ),
                    ),
                onRevoke: (memberUid) =>
                    _run(() => _repository.revokeMember(memberUid)),
              );
            },
          );
        },
      ),
    ),
    bottomNavigationBar: const FamilyBottomNavBar(selectedIndex: 4),
  );
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.members,
    required this.repository,
    required this.actionInProgress,
    required this.onInvite,
    required this.onLeave,
    required this.onLogout,
    required this.onNotificationChanged,
    required this.onPermissionChanged,
    required this.onRevoke,
  });

  final FamilyUserProfile profile;
  final List<FamilyMember> members;
  final FamilyRepository repository;
  final bool actionInProgress;
  final VoidCallback onInvite;
  final VoidCallback onLeave;
  final VoidCallback onLogout;
  final void Function(String key, bool enabled) onNotificationChanged;
  final void Function(
    String memberUid,
    FamilyPermissionType permission,
    bool enabled,
  )
  onPermissionChanged;
  final void Function(String memberUid) onRevoke;

  @override
  Widget build(BuildContext context) {
    final riders = members.where((member) => member.role == 'rider');
    final rider = riders.isEmpty ? null : riders.first;
    final guardians = members.where((member) => member.role == 'guardian');
    final isRider = profile.familyId == profile.uid;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
        _Panel(
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: NovaColors.pink,
                child: Text(
                  _initials(profile.name),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
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
                profile.email,
                style: const TextStyle(color: NovaColors.secondaryText),
              ),
              if (profile.phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  profile.phoneNumber,
                  style: const TextStyle(color: NovaColors.secondaryText),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                profile.relationship,
                style: const TextStyle(color: NovaColors.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle('FAMILY'),
        const SizedBox(height: 10),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rider != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: NovaColors.green,
                    child: Icon(Icons.two_wheeler, color: Colors.white),
                  ),
                  title: Text(
                    rider.displayName,
                    style: const TextStyle(color: NovaColors.primaryText),
                  ),
                  subtitle: const Text(
                    'Linked rider',
                    style: TextStyle(color: NovaColors.secondaryText),
                  ),
                )
              else
                const Text(
                  'No rider connection',
                  style: TextStyle(color: NovaColors.secondaryText),
                ),
              if (isRider) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: actionInProgress ? null : onInvite,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Create guardian invite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NovaColors.cyan,
                    foregroundColor: Colors.black,
                  ),
                ),
              ] else if (profile.familyId == null) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.guardianConnectPath),
                  child: const Text('Connect with an invite code'),
                ),
              ] else ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: actionInProgress ? null : onLeave,
                  child: const Text('Leave family'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle('NOTIFICATION SETTINGS'),
        const SizedBox(height: 10),
        _Panel(
          child: Column(
            children: [
              _SettingToggle(
                label: 'Emergency alerts',
                value: profile.notificationSettings['emergencyAlerts'] ?? true,
                enabled: !actionInProgress,
                onChanged: (value) =>
                    onNotificationChanged('emergencyAlerts', value),
              ),
              _SettingToggle(
                label: 'Accident detection',
                value:
                    profile.notificationSettings['accidentDetection'] ?? true,
                enabled: !actionInProgress,
                onChanged: (value) =>
                    onNotificationChanged('accidentDetection', value),
              ),
              _SettingToggle(
                label: 'Trip started',
                value: profile.notificationSettings['tripStarted'] ?? true,
                enabled: !actionInProgress,
                onChanged: (value) =>
                    onNotificationChanged('tripStarted', value),
              ),
              _SettingToggle(
                label: 'Rider offline',
                value: profile.notificationSettings['riderOffline'] ?? true,
                enabled: !actionInProgress,
                onChanged: (value) =>
                    onNotificationChanged('riderOffline', value),
              ),
              _SettingToggle(
                label: 'GPS signal lost',
                value: profile.notificationSettings['gpsSignalLost'] ?? true,
                enabled: !actionInProgress,
                onChanged: (value) =>
                    onNotificationChanged('gpsSignalLost', value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle('RIDER ACCESS'),
        const SizedBox(height: 10),
        if (isRider) ...[
          if (guardians.isEmpty)
            const _Panel(
              child: Text(
                'No guardians have joined yet.',
                style: TextStyle(color: NovaColors.secondaryText),
              ),
            )
          else
            ...guardians.map(
              (guardian) => _GuardianPermissions(
                guardian: guardian,
                enabled: !actionInProgress,
                onChanged: (permission, value) =>
                    onPermissionChanged(guardian.uid, permission, value),
                onRevoke: () => onRevoke(guardian.uid),
              ),
            ),
        ] else
          StreamBuilder<List<FamilyPermission>>(
            stream: repository.watchMyPermissions(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Panel(
                  child: Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: NovaColors.red),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _Panel(
                  child: Center(
                    child: CircularProgressIndicator(color: NovaColors.cyan),
                  ),
                );
              }
              return _Panel(
                child: Column(
                  children: (snapshot.data ?? const <FamilyPermission>[])
                      .map(
                        (permission) => _SettingToggle(
                          label: permission.label,
                          value: permission.enabled,
                          enabled: false,
                          onChanged: (_) {},
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        const SizedBox(height: 22),
        const _SectionTitle('ACCOUNT'),
        const SizedBox(height: 10),
        _Panel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: NovaColors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.white)),
            onTap: actionInProgress ? null : onLogout,
          ),
        ),
      ],
    );
  }

  static String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

class _GuardianPermissions extends StatelessWidget {
  const _GuardianPermissions({
    required this.guardian,
    required this.enabled,
    required this.onChanged,
    required this.onRevoke,
  });

  final FamilyMember guardian;
  final bool enabled;
  final void Function(FamilyPermissionType permission, bool value) onChanged;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) => _Panel(
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          guardian.displayName,
          style: const TextStyle(
            color: NovaColors.primaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final permission in FamilyPermissionType.values)
          _SettingToggle(
            label: _permissionLabel(permission),
            value: guardian.permissions[_permissionKey(permission)] ?? false,
            enabled: enabled,
            onChanged: (value) => onChanged(permission, value),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: enabled ? onRevoke : null,
            child: const Text(
              'Remove guardian',
              style: TextStyle(color: NovaColors.red),
            ),
          ),
        ),
      ],
    ),
  );
}

String _permissionKey(FamilyPermissionType permission) => switch (permission) {
  FamilyPermissionType.liveLocation => 'liveLocation',
  FamilyPermissionType.emergencyAlerts => 'emergencyAlerts',
  FamilyPermissionType.tripStatus => 'tripStatus',
  FamilyPermissionType.helmetStatus => 'helmetStatus',
  FamilyPermissionType.incidentHistory => 'incidentHistory',
};

String _permissionLabel(FamilyPermissionType permission) =>
    switch (permission) {
      FamilyPermissionType.liveLocation => 'Live location',
      FamilyPermissionType.emergencyAlerts => 'Emergency alerts',
      FamilyPermissionType.tripStatus => 'Trip status',
      FamilyPermissionType.helmetStatus => 'Helmet status',
      FamilyPermissionType.incidentHistory => 'Incident history',
    };

class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    activeColor: NovaColors.cyan,
    title: Text(
      label,
      style: const TextStyle(color: NovaColors.primaryText, fontSize: 13),
    ),
    value: value,
    onChanged: enabled ? onChanged : null,
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: margin,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: NovaColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: NovaColors.cardBorder),
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: NovaColors.secondaryText,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: NovaColors.secondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
