import 'package:flutter/material.dart';

/// Color palette used across the NovaRide rider app and admin dashboard.
/// Single source of truth — keeping these in one place makes it easy to
/// re-theme later and keeps the two entrypoints visually consistent.
class NovaColors {
  static const background = Color(0xFF0A0E1A);
  static const card = Color(0xFF12172A);
  static const cardBorder = Color(0xFF1E2438);
  static const primaryText = Colors.white;
  static const secondaryText = Color(0xFF8993A8);
  static const green = Color(0xFF3DDC97);
  static const cyan = Color(0xFF4CC9F0);
  static const pink = Color(0xFFEF476F);
  static const red = Color(0xFFFF3B5C);

  /// Chart series accents — used by the admin dashboard panels.
  static const amber = Color(0xFFFFB020);
  static const purple = Color(0xFF9B5DE5);
}
