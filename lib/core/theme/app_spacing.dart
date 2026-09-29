/// Spacing, radii and durations.
///
/// Signal separates things with space rather than lines, which only works
/// if the spacing is systematic — an 18 here and a 22 there reads as
/// sloppiness, not as rhythm. Everything below is a multiple of 4.
///
/// These are plain constants, unlike [AppColors]: a light theme changes
/// what things look like, not how far apart they sit.
library;

abstract final class AppSpacing {
  /// Between an icon and its label.
  static const double xs = 4;

  /// Between tightly related lines of text.
  static const double sm = 8;

  /// Inside a chip or a small control.
  static const double md = 12;

  /// The default gap, and a card's inner padding.
  static const double lg = 16;

  /// Between fields in a form.
  static const double xl = 20;

  /// Between a heading and its content; the screen's side gutter.
  static const double xxl = 28;

  /// Between sections.
  static const double xxxl = 40;

  /// The page gutter. One number so every screen's left edge lines up.
  static const double gutter = 28;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;

  /// Cards and sheets.
  static const double lg = 16;

  /// Buttons and chips, which read as fully rounded at these heights.
  static const double pill = 999;
}

abstract final class AppSizes {
  /// Every tappable thing is at least this tall. Riders wear gloves.
  static const double minTouchTarget = 48;

  /// Primary buttons.
  static const double buttonHeight = 54;

  /// A text field's tap area, underline included.
  static const double fieldHeight = 56;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
}
