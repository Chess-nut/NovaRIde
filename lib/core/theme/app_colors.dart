import 'package:flutter/material.dart';

/// The mobile app's semantic colour tokens.
///
/// **Direction: Signal.** Two rules hold the palette together, and both are
/// worth keeping when adding to it:
///
/// 1. **One action colour.** [action] is the only saturated thing on a
///    screen that a person is meant to press. If two things on one screen
///    are green, one of them is wrong.
/// 2. **Colour elsewhere always means status.** [safe], [warning],
///    [critical] and the rest carry meaning. Nothing is coloured to look
///    nice; an accent used decoratively spends the attention the critical
///    states need.
///
/// **This is a [ThemeExtension], not a class of constants, on purpose.** A
/// widget reads `context.colors.action`, which resolves through the
/// [Theme]. Adding a light theme later is then a matter of writing a second
/// [AppColors] instance and passing it to [ThemeData] — no widget changes,
/// no conditionals at call sites. That is why there are no `static const`
/// colours here for widgets to reach past the theme and grab.
///
/// Only [dark] exists today. [light] is deliberately absent rather than a
/// half-done copy: the point of this structure is that adding it is cheap,
/// not that it has already been started.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.action,
    required this.actionPressed,
    required this.actionDisabled,
    required this.onAction,
    required this.safe,
    required this.riding,
    required this.warning,
    required this.critical,
    required this.sos,
    required this.offline,
    required this.resolved,
    required this.accentViolet,
    required this.scrim,
  });

  // ---- surfaces --------------------------------------------------------
  // Neutral charcoal rather than navy: navy reads as a product's brand
  // colour, and in Signal the only brand colour is the green.

  /// The page behind everything.
  final Color surface;

  /// Cards, sheets, anything sitting above the page.
  final Color surfaceRaised;

  /// Wells — an input's fill, a progress track. Below the page, not above.
  final Color surfaceSunken;

  /// Hairlines. Used sparingly: Signal separates with space, not lines.
  final Color border;

  /// A border that has to be seen — a focused field's rest state, a
  /// divider that carries meaning.
  final Color borderStrong;

  // ---- content ---------------------------------------------------------

  /// Headings and anything being read closely.
  final Color textPrimary;

  /// Supporting copy. Passes AA on [surface] at 15px and above.
  final Color textSecondary;

  /// Labels, timestamps, disabled text. Not for anything that must be
  /// read — it does not pass AA at body size.
  final Color textMuted;

  // ---- action ----------------------------------------------------------

  /// The one thing on screen to press.
  final Color action;
  final Color actionPressed;
  final Color actionDisabled;

  /// Text and icons on top of [action]. Dark, not white: the green is
  /// bright enough that white on it fails contrast.
  final Color onAction;

  // ---- status ----------------------------------------------------------
  // The seven the guardian dashboards need, named for what they mean
  // rather than what they look like.

  /// Nothing wrong. Deliberately the same value as [action] — "safe" and
  /// "go" are the same idea — but a separate token, so a later theme can
  /// split them without hunting through widgets.
  final Color safe;

  /// A trip is in progress.
  final Color riding;

  /// Something needs attention but nobody is hurt — alcohol detected, a
  /// low battery.
  final Color warning;

  /// A crash has been detected.
  final Color critical;

  /// The rider pressed the button themselves.
  final Color sos;

  /// The helmet has not reported recently.
  final Color offline;

  /// An incident that has been closed out.
  final Color resolved;

  /// Legacy accent from the rider alerts screen, kept so Phase 2 does not
  /// change a screen Phase 7 owns. It breaks rule 2 above; when Phase 7
  /// reworks that screen this token should go with it.
  final Color accentViolet;

  /// Behind modals and sheets.
  final Color scrim;

  /// The only palette that exists. See the class comment.
  static const AppColors dark = AppColors(
    surface: Color(0xFF0E1116),
    surfaceRaised: Color(0xFF171B22),
    surfaceSunken: Color(0xFF0A0D12),
    border: Color(0xFF252B35),
    borderStrong: Color(0xFF39414E),
    textPrimary: Color(0xFFECEFF4),
    textSecondary: Color(0xFF9AA4B2),
    textMuted: Color(0xFF69737F),
    action: Color(0xFF3DDC97),
    actionPressed: Color(0xFF2FBF80),
    actionDisabled: Color(0xFF24493B),
    onAction: Color(0xFF07211A),
    safe: Color(0xFF3DDC97),
    riding: Color(0xFF4CC9F0),
    warning: Color(0xFFF5A623),
    critical: Color(0xFFFF3B5C),
    sos: Color(0xFFEF476F),
    offline: Color(0xFF6C7280),
    resolved: Color(0xFF7DD3FC),
    accentViolet: Color(0xFF9B6BFF),
    scrim: Color(0x99000000),
  );

  @override
  AppColors copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? action,
    Color? actionPressed,
    Color? actionDisabled,
    Color? onAction,
    Color? safe,
    Color? riding,
    Color? warning,
    Color? critical,
    Color? sos,
    Color? offline,
    Color? resolved,
    Color? accentViolet,
    Color? scrim,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      action: action ?? this.action,
      actionPressed: actionPressed ?? this.actionPressed,
      actionDisabled: actionDisabled ?? this.actionDisabled,
      onAction: onAction ?? this.onAction,
      safe: safe ?? this.safe,
      riding: riding ?? this.riding,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
      sos: sos ?? this.sos,
      offline: offline ?? this.offline,
      resolved: resolved ?? this.resolved,
      accentViolet: accentViolet ?? this.accentViolet,
      scrim: scrim ?? this.scrim,
    );
  }

  /// Flutter animates between themes when [ThemeData] changes, so this has
  /// to exist. It will start mattering the day a light theme lands.
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppColors(
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceSunken: mix(surfaceSunken, other.surfaceSunken),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      action: mix(action, other.action),
      actionPressed: mix(actionPressed, other.actionPressed),
      actionDisabled: mix(actionDisabled, other.actionDisabled),
      onAction: mix(onAction, other.onAction),
      safe: mix(safe, other.safe),
      riding: mix(riding, other.riding),
      warning: mix(warning, other.warning),
      critical: mix(critical, other.critical),
      sos: mix(sos, other.sos),
      offline: mix(offline, other.offline),
      resolved: mix(resolved, other.resolved),
      accentViolet: mix(accentViolet, other.accentViolet),
      scrim: mix(scrim, other.scrim),
    );
  }
}

/// `context.colors.action` — the only way a widget should reach a colour.
///
/// Falls back to [AppColors.dark] rather than throwing if the extension is
/// missing, so a widget pumped in a bare `MaterialApp` in a test still
/// renders. A missing extension is a wiring bug, not a reason for a screen
/// to be blank.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
