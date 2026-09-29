import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds [ThemeData] from a palette.
///
/// **The important property of this file is that it takes the palette as
/// an argument.** Nothing below hardcodes a dark value; every colour comes
/// from the [AppColors] passed in, and the palette travels with the theme
/// as a [ThemeExtension] so widgets resolve tokens through [Theme] rather
/// than importing constants. Adding a light theme is therefore:
///
/// 1. write `AppColors.light`,
/// 2. pass `AppTheme.from(AppColors.light)` as `MaterialApp.theme`,
/// 3. set `themeMode` to something other than `ThemeMode.dark`.
///
/// No widget changes, no `if (isDark)` at any call site. That was the
/// brief for Phase 2, and [from] is where it is kept or broken — a literal
/// colour appearing anywhere in this file is the thing to catch in review.
///
/// [brightness] is passed separately because it is not derivable from the
/// tokens: it tells Flutter which system chrome and default overlays to
/// use, and only the palette's author knows.
abstract final class AppTheme {
  static ThemeData from(
    AppColors colors, {
    Brightness brightness = Brightness.dark,
  }) {
    final textTheme =
        AppTypography.textTheme(colors.textPrimary, colors.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      extensions: [colors],
      textTheme: textTheme,

      // Material's own scheme still drives components this app has not
      // themed explicitly, so it is mapped onto the same tokens rather
      // than left to Flutter's defaults — otherwise a stray Material
      // widget arrives in a colour from nowhere.
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.action,
        onPrimary: colors.onAction,
        secondary: colors.riding,
        onSecondary: colors.onAction,
        error: colors.critical,
        onError: colors.textPrimary,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.surfaceRaised,
        outline: colors.border,
        outlineVariant: colors.borderStrong,
        scrim: colors.scrim,
      ),

      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: colors.textSecondary),
      ),

      // The one saturated control. Dark label on the green, because white
      // on this green does not pass contrast.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.action,
          foregroundColor: colors.onAction,
          disabledBackgroundColor: colors.actionDisabled,
          disabledForegroundColor: colors.textMuted,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: AppTypography.title,
        ),
      ),

      // Secondary actions. An outline, never a second filled button — one
      // action colour per screen is the whole discipline.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          side: BorderSide(color: colors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: AppTypography.title,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textSecondary,
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          textStyle: AppTypography.label,
        ),
      ),

      // Underline fields, not boxes: Signal's forms are lines and space.
      // The underline is the status channel — it turns green on focus and
      // red on error, which is why errorStyle below must never be left to
      // the zero-height default that hides the message.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        labelStyle: AppTypography.label.copyWith(color: colors.textSecondary),
        floatingLabelStyle:
            AppTypography.label.copyWith(color: colors.textSecondary),
        hintStyle: AppTypography.body.copyWith(color: colors.textMuted),
        helperStyle: AppTypography.caption.copyWith(color: colors.textMuted),
        errorStyle: AppTypography.caption.copyWith(color: colors.critical),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colors.action, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colors.critical),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colors.critical, width: 2),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colors.border),
        ),
        prefixIconColor: colors.textMuted,
        suffixIconColor: colors.textMuted,
      ),

      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: AppTypography.body.copyWith(color: colors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.action,
        linearTrackColor: colors.surfaceSunken,
        circularTrackColor: colors.surfaceSunken,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.action
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(colors.onAction),
        side: BorderSide(color: colors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      iconTheme: IconThemeData(color: colors.textSecondary),
    );
  }

  /// The only theme that exists today.
  static ThemeData get dark => from(AppColors.dark);
}
