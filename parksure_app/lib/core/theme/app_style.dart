import 'package:flutter/material.dart';

/// Single source of truth for ParkSure's look: colors, text styles and sizes.
///
/// Values follow the UX Pilot design (minimal black/white UI with four
/// curb-status colors). Use these everywhere instead of hard-coding values:
///
///   Text('Allowed', style: AppStyle.title.copyWith(color: AppStyle.allowed))
///   Padding(padding: const EdgeInsets.all(AppStyle.spaceMd), ...)
abstract final class AppStyle {
  // ───────────────────────── Colors ─────────────────────────

  // Brand / neutrals
  static const Color black = Color(0xFF111111);
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5); // map blocks, inputs
  static const Color border = Color(0xFFE5E5E5);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF9E9E9E);

  // Dark mode neutrals (MapDark screen)
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA1A1A6);

  // Curb status (the verdict colors)
  static const Color allowed = Color(0xFF1E8E3E); // green
  static const Color notAllowed = Color(0xFFD93025); // red
  static const Color conditions = Color(0xFFE0A100); // amber
  static const Color unknown = Color(0xFF8A8A8A); // grey

  // Feedback
  static const Color error = notAllowed;

  // ───────────────────────── Fonts ─────────────────────────

  /// null = platform default (Roboto / SF). Set to 'Inter' once the font
  /// is added to pubspec.yaml.
  static const String? fontFamily = null;

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.5,
  ); // big clock "09:30"

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  ); // "Allowed", "Not allowed"

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  ); // "Which side?", "SRR permit sector"

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  ); // "Rue Rivard · east side"

  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textMuted,
  ); // disclaimer footer, map labels

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: white,
  );

  // ───────────────────────── Spacing ─────────────────────────

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // ───────────────────────── Radius ─────────────────────────

  static const double radiusSm = 8; // inputs, small cards
  static const double radiusMd = 12; // cards
  static const double radiusLg = 20; // bottom sheets, dialogs
  static const double radiusPill = 999; // buttons, chips, top bar

  // ───────────────────────── Sizes ─────────────────────────

  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double buttonHeight = 48;
  static const double topBarHeight = 44;
  static const double curbStrokeWidth = 4; // curb lines on the map
  static const double statusBarWidth = 3; // vertical bar before "Allowed"
}
