/// Screen headers, list rows, notes and empty states for the rider
/// screens, on Signal. Companion to `nova_surfaces.dart`.
///
/// Icons in rows are drawn in the secondary colour, never a decorative
/// accent: in Signal, colour means status, and a pink "Emergency
/// contacts" icon next to a green "Helmet settings" one says nothing
/// about either.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'nova_surfaces.dart';

/// The page gutter for the rider screens. Matches Home.
const kRiderGutter = AppSpacing.xl;

/// A screen's title, and a way back when there is somewhere to go back to.
///
/// The back button is a real 48px [IconButton] with a "Back" tooltip — the
/// old headers used a 36px [GestureDetector] that a screen reader did not
/// know was a button.
class NovaScreenHeader extends StatelessWidget {
  const NovaScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// False on a tab's root screen, which the bottom nav reaches.
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        showBack ? AppSpacing.sm : kRiderGutter,
        AppSpacing.sm,
        kRiderGutter,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(AppSizes.minTouchTarget),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: context.text.h1),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodyMuted),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Rows on one card, separated by hairlines inset past the icon.
class NovaListGroup extends StatelessWidget {
  const NovaListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return NovaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.lg + 24 + AppSpacing.lg,
                color: colors.border,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row in a [NovaListGroup]: an icon, a title, an optional subtitle,
/// and a chevron when it goes somewhere.
///
/// At least 56px tall, the whole row tappable. A row without [onTap] is
/// information, not a dead button: no chevron, no ripple.
class NovaListRow extends StatelessWidget {
  const NovaListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.tone = NovaTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the chevron — a value, a pill, a switch.
  final Widget? trailing;

  /// Critical for a destructive row ("Delete"), so the icon and title say
  /// so. Anything else stays neutral.
  final NovaTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final destructive = tone == NovaTone.critical;
    final iconColor = destructive ? colors.critical : colors.textSecondary;
    final titleColor = destructive ? colors.critical : colors.textPrimary;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: context.text.title.copyWith(color: titleColor)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: context.text.caption),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// A row with a switch. A null [onChanged] draws the switch disabled —
/// for a setting the app shows but cannot change yet — and the whole row
/// is announced as one control either way.
class NovaSwitchRow extends StatelessWidget {
  const NovaSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return MergeSemantics(
      child: NovaListRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: enabled ? () => onChanged!(!value) : null,
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// A label and its value on one line — "Latitude  14.30416° N".
class NovaValueRow extends StatelessWidget {
  const NovaValueRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: context.text.bodyMuted)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.text.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// A short note that explains a limit — "These aren't saved yet." Tinted
/// in [tone]; neutral by default, warning when the limit can bite.
class NovaNote extends StatelessWidget {
  const NovaNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.tone = NovaTone.neutral,
  });

  final String text;
  final IconData icon;
  final NovaTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final emphasised = tone == NovaTone.warning || tone == NovaTone.critical;
    return NovaCard(
      tone: emphasised ? tone : NovaTone.neutral,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: emphasised ? tone.colorIn(colors) : colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: emphasised ? context.text.body : context.text.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// What a list shows when there is nothing in it, and why.
class NovaEmptyState extends StatelessWidget {
  const NovaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return NovaCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: colors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: context.text.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: context.text.bodyMuted,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A full-width outlined button in the critical colour, for actions that
/// end something — "Log out". The one primary action on a screen stays
/// `NovaPrimaryButton`.
class NovaDestructiveButton extends StatelessWidget {
  const NovaDestructiveButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.critical,
          side: BorderSide(color: colors.critical),
          shape: const StadiumBorder(),
          textStyle: AppTypography.title,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

/// A full-width outlined button for a second action beside a
/// `NovaPrimaryButton` — "Add phone contact", "Open map".
class NovaSecondaryButton extends StatelessWidget {
  const NovaSecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderStrong),
          shape: const StadiumBorder(),
          textStyle: AppTypography.title,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

/// "12 s ago", "4 min ago", "2 h ago", "3 d ago" — short enough for one
/// line. Shared so every rider screen words time the same way.
String novaTimeAgo(DateTime then, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(then);
  if (diff.isNegative || diff.inSeconds < 5) return 'just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds} s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
