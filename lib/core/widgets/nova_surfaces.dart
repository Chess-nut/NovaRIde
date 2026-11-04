/// The rider screens' shared building blocks, all on Signal.
///
/// Before these, every rider screen drew its own card, pill and status dot
/// from `NovaColors` with hand-picked sizes — 182 literal font sizes
/// across the features, some as small as 9px. These read `context.colors`, `context.text` and
/// [AppSpacing] only, so a screen built from them cannot drift from the
/// system, and a change to the system reaches every screen at once.
///
/// Status is never colour alone: every [NovaTone] that reaches the screen
/// arrives with words ([NovaStatusLine], [NovaPill]), because a rider in
/// sunlight — or one who is colour-blind — has to be able to read it.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// What a piece of status means. Resolved to a colour through the theme,
/// so a widget says "warning", never "amber".
enum NovaTone {
  /// No judgement: a label, a number with nothing to say about it.
  neutral,

  /// Nothing wrong; the helmet is live.
  safe,

  /// Needs attention, nobody hurt: alcohol, an odd posture, stale data.
  warning,

  /// Something failed or someone may be hurt.
  critical,

  /// Not reporting. Grey, and always paired with words.
  offline;

  /// The tone's own colour, for dots, icons and emphasised text.
  Color colorIn(AppColors colors) => switch (this) {
    NovaTone.neutral => colors.textSecondary,
    NovaTone.safe => colors.safe,
    NovaTone.warning => colors.warning,
    NovaTone.critical => colors.critical,
    NovaTone.offline => colors.offline,
  };

  /// Text in this tone. Offline's grey fails contrast as text (3.6:1 on a
  /// card), so offline words are drawn in the secondary colour and only
  /// the dot is grey.
  Color textIn(AppColors colors) => switch (this) {
    NovaTone.offline || NovaTone.neutral => colors.textSecondary,
    _ => colorIn(colors),
  };

  /// A card or pill background tinted toward the tone. 8% keeps every
  /// tone's own text above 4.5:1 on it; critical red falls below that at
  /// 14%.
  Color tintOver(Color base, AppColors colors) => switch (this) {
    NovaTone.neutral || NovaTone.offline => base,
    _ => Color.alphaBlend(colorIn(colors).withValues(alpha: 0.08), base),
  };
}

/// A raised surface: Signal's card.
///
/// With [onTap] it is a button — ripple, a semantic button role, and the
/// whole card as the hit area. A [tone] other than neutral tints it and
/// draws a 1px border in the tone, for the one card on screen that needs
/// to be noticed.
class NovaCard extends StatelessWidget {
  const NovaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.semanticLabel,
    this.tone = NovaTone.neutral,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// What a screen reader says for a tappable card. Without it the
  /// card's text is read in order, which is usually fine.
  final String? semanticLabel;
  final NovaTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final emphasised = tone != NovaTone.neutral && tone != NovaTone.offline;

    final card = Material(
      color: tone.tintOver(colors.surfaceRaised, colors),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: emphasised
            ? BorderSide(color: tone.colorIn(colors))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );

    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: card,
    );
  }
}

/// A short status in words, led by a dot — or by [icon] when the status
/// needs more than a dot to be read without colour (an up-arrow for
/// "above threshold").
class NovaStatusLine extends StatelessWidget {
  const NovaStatusLine({
    super.key,
    required this.text,
    required this.tone,
    this.icon,
  });

  final String text;
  final NovaTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final emphasised = tone == NovaTone.warning || tone == NovaTone.critical;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 14, color: tone.colorIn(colors))
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tone.colorIn(colors),
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: AppSpacing.xs + 2),
        Flexible(
          child: Text(
            text,
            style: context.text.caption.copyWith(
              color: emphasised ? tone.textIn(colors) : colors.textSecondary,
              fontWeight: emphasised ? FontWeight.w500 : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// A rounded label — "Live", "Offline". Words in the tone's colour on an
/// 8% tint of it.
class NovaPill extends StatelessWidget {
  const NovaPill({super.key, required this.label, required this.tone});

  final String label;
  final NovaTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quiet = tone == NovaTone.neutral || tone == NovaTone.offline;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: quiet
            ? colors.border
            : tone.tintOver(colors.surfaceRaised, colors),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: context.text.label.copyWith(color: tone.textIn(colors)),
      ),
    );
  }
}

/// The small heading above a group of cards — "Sensors". Sentence case,
/// secondary colour: it orients, it does not compete with the cards.
class NovaSectionLabel extends StatelessWidget {
  const NovaSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: context.text.labelMuted),
    );
  }
}
