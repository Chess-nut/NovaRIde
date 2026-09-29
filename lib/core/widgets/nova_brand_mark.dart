import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// The helmet roundel.
///
/// Extracted here because the splash screen and the verify-email screen
/// both need it and neither should own it. The Welcome screen still draws
/// its own copy privately; Phase 2 collapses that one onto this widget
/// rather than doing it twice under a palette that is about to change.
class NovaLogoMark extends StatelessWidget {
  const NovaLogoMark({super.key, this.size = 108});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NovaColors.card,
        border: Border.all(color: NovaColors.cyan, width: 1.5),
      ),
      child: Icon(
        Icons.sports_motorsports,
        color: NovaColors.cyan,
        size: size * 0.44,
      ),
    );
  }
}

/// "Nova" in white, "Ride" in cyan — the wordmark, at whatever size.
class NovaWordmark extends StatelessWidget {
  const NovaWordmark({super.key, this.fontSize = 32});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        children: const [
          TextSpan(text: 'Nova', style: TextStyle(color: NovaColors.primaryText)),
          TextSpan(text: 'Ride', style: TextStyle(color: NovaColors.cyan)),
        ],
      ),
    );
  }
}
