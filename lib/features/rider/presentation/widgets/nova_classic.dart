/// The original NovaRide look, as shared pieces: the dark rounded card,
/// the bold section title, the coloured icon circle, the status pill,
/// and the page header with a back arrow.
///
/// The rider screens went back to this look (Home, Alerts, Analytics,
/// Notifications, Map, Profile). Colours come from `shared/theme.dart`.
/// One change from the old screens throughout: no text under 12px, so
/// everything can be read off a phone on a handlebar mount.
library;

import 'package:flutter/material.dart';

import 'package:novaride/core/widgets/nova_surfaces.dart' show NovaTone;
import 'package:novaride/shared/theme.dart';

/// Dark, rounded, hairline border. Tappable when [onTap] is set.
class ClassicCard extends StatelessWidget {
  const ClassicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    // The ink has to be drawn above the card's colour, so the Material
    // sits inside the decorated box, not around it.
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? NovaColors.cardBorder),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: tap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: tap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

/// "Alert History", "Current Location" — white, bold, 15px.
class ClassicSectionTitle extends StatelessWidget {
  const ClassicSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: const TextStyle(
          color: NovaColors.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// "ACCOUNT", "TODAY" — grey, uppercase, letter-spaced.
class ClassicCapsLabel extends StatelessWidget {
  const ClassicCapsLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          color: NovaColors.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// An icon on a tinted circle of its own colour.
class ClassicIconCircle extends StatelessWidget {
  const ClassicIconCircle({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

/// A rounded badge with a dot: "Live", "No helmet paired", "Resolved".
class ClassicPill extends StatelessWidget {
  const ClassicPill({
    super.key,
    required this.label,
    required this.color,
    this.dot = true,
  });

  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Icon(Icons.circle, color: color, size: 7),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Title and subtitle, with a back arrow when the page was pushed.
class ClassicHeader extends StatelessWidget {
  const ClassicHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: NovaColors.primaryText),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: showBack ? 0 : 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A one-line card for "nothing here", with the reason.
class ClassicNotice extends StatelessWidget {
  const ClassicNotice({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.title,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String? title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClassicCard(
      onTap: onTap,
      child: Row(
        children: [
          ClassicIconCircle(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      color: NovaColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The old palette's colour for a status tone.
Color classicToneColor(NovaTone tone) => switch (tone) {
  NovaTone.safe => NovaColors.green,
  NovaTone.warning => NovaColors.amber,
  NovaTone.critical => NovaColors.red,
  _ => NovaColors.secondaryText,
};

/// "Nov 6, 2026 at 4:20 AM", in the phone's time zone.
String classicDateTime(DateTime at) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final t = at.toLocal();
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  return '${months[t.month - 1]} ${t.day}, ${t.year} at $h:$m $ampm';
}
