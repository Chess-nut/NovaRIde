import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The helmet roundel.
///
/// In Signal the mark is a thin outline rather than a filled badge: the
/// green is the action colour and spending it on decoration is exactly
/// what the direction forbids. It reads as a line drawing, and the only
/// saturated thing on the screen stays the button.
class NovaLogoMark extends StatelessWidget {
  const NovaLogoMark({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.border, width: 1.5),
      ),
      child: Icon(
        Icons.sports_motorsports_outlined,
        color: colors.textSecondary,
        size: size * 0.44,
      ),
    );
  }
}

/// "Nova" in the primary text colour, "Ride" in the action colour.
///
/// The one place the accent is used for something other than a control,
/// and it earns it: this is the wordmark, and it appears once per screen
/// at most.
class NovaWordmark extends StatelessWidget {
  const NovaWordmark({super.key, this.fontSize = 24, this.textAlign});

  final double fontSize;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RichText(
      textAlign: textAlign ?? TextAlign.center,
      text: TextSpan(
        style: AppTypography.h1.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: 'Nova', style: TextStyle(color: colors.textPrimary)),
          TextSpan(text: 'Ride', style: TextStyle(color: colors.action)),
        ],
      ),
    );
  }
}
