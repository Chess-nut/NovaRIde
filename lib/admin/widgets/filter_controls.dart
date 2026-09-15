import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// Small uppercase caption naming a group of filter chips.
class FilterGroupLabel extends StatelessWidget {
  final String text;

  const FilterGroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: NovaColors.secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

/// Toggleable filter pill.
///
/// Hand-rolled rather than Material's FilterChip, which needs a pile of theme
/// overrides to sit correctly on the dark console palette. Shared by the
/// alerts page, the dispatch dialog and the rider roster.
class FilterChipButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const FilterChipButton({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.18) : NovaColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.65)
                  : NovaColors.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : NovaColors.secondaryText,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
