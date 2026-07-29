import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// Shared chrome for every dashboard panel: squared-off card, uppercase
/// micro-title, and an overflow affordance. Deliberately tighter and squarer
/// than the rider app's cards — this is an operations console, not a phone.
class DashPanel extends StatelessWidget {
  final String title;

  /// Sits between the title and the overflow dot — a count, a status, nothing.
  final Widget? trailing;

  /// The map panel bleeds to the edges, so the 12px inset is overridable.
  final EdgeInsets contentPadding;
  final Widget child;

  const DashPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.contentPadding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                ?trailing,
                const SizedBox(width: 6),
                // Visual only — the panel menu lands with real actions later.
                const Icon(
                  Icons.more_vert,
                  size: 16,
                  color: NovaColors.secondaryText,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(padding: contentPadding, child: child),
          ),
        ],
      ),
    );
  }
}
