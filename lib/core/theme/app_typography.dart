import 'package:flutter/material.dart';

/// The Signal type scale.
///
/// Seven steps, one family, a wide weight range. The direction leans on
/// typography rather than colour for hierarchy, which means the steps have
/// to be far enough apart to do that work — 36 / 24 / 19 / 16 / 15 / 13 /
/// 12, not a dozen sizes two points apart.
///
/// Headings use tight tracking (−0.2) and body copy uses generous line
/// height (1.47). That pairing is most of the "quiet, editorial" feel: the
/// headings pull together, the paragraphs open up.
///
/// **On the font family.** Signal was specified with Inter. This ships on
/// Roboto — the SDK's own face, already bundled, already what the layout
/// tests measure against. Adding Inter means committing four binary font
/// files and a `fonts:` block, which is a repository decision rather than
/// a styling one; [fontFamily] is the single line that changes if it is
/// made. The scale, weights and tracking below are what carry the
/// direction, and they carry it in Roboto.
///
/// Sizes are not read from here by feature code directly — widgets use
/// `context.text.body`, which resolves through the [Theme].
abstract final class AppTypography {
  /// Swap to 'Inter' here and add the `fonts:` block to pubspec.yaml.
  static const String fontFamily = 'Roboto';

  /// The largest thing on a screen. One per screen, at most.
  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    height: 42 / 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  /// A screen's own title — "Welcome back".
  static const h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// A section inside a screen.
  static const h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    height: 26 / 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  /// A card heading, a list row's main line, a button label.
  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Running copy. The default for anything unspecified.
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );

  /// Field labels, chips, metadata.
  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  /// Timestamps, helper text, legal small print.
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Material's slots, filled from the scale above so that any widget
  /// which reads the [TextTheme] — and every Material component does —
  /// lands on the same seven steps.
  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displaySmall: display.copyWith(color: primary),
      headlineMedium: h1.copyWith(color: primary),
      headlineSmall: h2.copyWith(color: primary),
      titleMedium: title.copyWith(color: primary),
      titleSmall: label.copyWith(color: primary),
      bodyLarge: body.copyWith(color: primary),
      bodyMedium: body.copyWith(color: secondary),
      bodySmall: caption.copyWith(color: secondary),
      labelLarge: title.copyWith(color: primary),
      labelMedium: label.copyWith(color: secondary),
      labelSmall: caption.copyWith(color: secondary),
    ).apply(fontFamily: fontFamily);
  }
}

/// `context.text.h1` — the scale, already coloured by the theme.
///
/// Reads from the resolved [TextTheme], so a style picked up here is the
/// one the theme actually installed, not a constant that happens to match.
extension AppTypographyContext on BuildContext {
  AppTextStyles get text => AppTextStyles(Theme.of(this).textTheme);
}

/// The scale as resolved styles. Constructed by [AppTypographyContext];
/// no reason to build one directly.
class AppTextStyles {
  const AppTextStyles(this._t);

  final TextTheme _t;

  TextStyle get display => _t.displaySmall!;
  TextStyle get h1 => _t.headlineMedium!;
  TextStyle get h2 => _t.headlineSmall!;
  TextStyle get title => _t.titleMedium!;
  TextStyle get body => _t.bodyLarge!;

  /// Body copy in the secondary colour — the common case for supporting
  /// text, saved from being `body.copyWith(color: …)` at every call site.
  TextStyle get bodyMuted => _t.bodyMedium!;
  TextStyle get label => _t.titleSmall!;
  TextStyle get labelMuted => _t.labelMedium!;
  TextStyle get caption => _t.bodySmall!;
}
