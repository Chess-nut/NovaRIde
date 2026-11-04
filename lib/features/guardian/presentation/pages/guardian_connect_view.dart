import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../../../core/widgets/nova_lists.dart';
import '../../../../core/widgets/nova_surfaces.dart';
import '../../../../core/widgets/nova_text_field.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/guardian_link.dart';

/// "Connect to a rider" — what a guardian sees until they follow someone.
///
/// One field for the 6-character code (spaces and dashes are ignored,
/// letters are upper-cased as they type), a choice of relationship, and
/// one button. Looking the code up and linking are one tap; errors say
/// what to do: check the code, ask for a new one, or unlink first.
///
/// Linking flips `myGuardianLinkProvider`, and Home swaps this view for
/// the rider's dashboard on its own.
class GuardianConnectView extends ConsumerStatefulWidget {
  const GuardianConnectView({super.key});

  @override
  ConsumerState<GuardianConnectView> createState() =>
      _GuardianConnectViewState();
}

class _GuardianConnectViewState extends ConsumerState<GuardianConnectView> {
  final _code = TextEditingController();
  String? _relationship;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _ready =>
      isWellFormedInviteCode(normaliseInviteCode(_code.text)) &&
      _relationship != null;

  Future<void> _connect() async {
    final profile = ref.read(authStateProvider).profile;
    if (profile == null || !_ready || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(guardianLinkRepositoryProvider).redeem(
            code: _code.text,
            guardianUid: profile.uid,
            // Must equal users/{uid}.fullName — the rules check it, so the
            // rider sees who really linked.
            guardianName: profile.fullName,
            relationship: _relationship!,
          );
    } on Failure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          kRiderGutter, AppSpacing.xl, kRiderGutter, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NovaTextField(
            label: 'Invite code',
            hint: 'K7P 2QM',
            controller: _code,
            prefixIcon: Icons.vpn_key_outlined,
            textInputAction: TextInputAction.done,
            maxLength: 7,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
              _UpperCase(),
            ],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            child: Text('They are your…', style: context.text.labelMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final r in kGuardianRelationships)
                ChoiceChip(
                  label: Text(r),
                  selected: _relationship == r,
                  showCheckmark: false,
                  labelStyle: context.text.body.copyWith(
                    color: _relationship == r
                        ? colors.action
                        : colors.textPrimary,
                  ),
                  backgroundColor: colors.surface,
                  selectedColor: colors.action.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: _relationship == r
                        ? colors.action.withValues(alpha: 0.5)
                        : colors.borderStrong,
                  ),
                  shape: const StadiumBorder(),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() {
                    _relationship = r;
                    _error = null;
                  }),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            NovaNote(
              tone: NovaTone.critical,
              icon: Icons.error_outline,
              text: _error!,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          NovaPrimaryButton(
            label: 'Connect to rider',
            busy: _busy,
            onPressed: _ready ? _connect : null,
          ),
          const SizedBox(height: AppSpacing.xxl),
          NovaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Where to get the code', style: context.text.title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Ask the rider to open NovaRide › Profile › Emergency '
                  'contacts › Invite a guardian. The code works for 15 '
                  'minutes.',
                  style: context.text.bodyMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
