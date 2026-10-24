import 'package:flutter/material.dart';

/// Brand tokens — mirrors STYLE_GUIDE.md (`COLORS` in theme.js).
/// Add new colours here rather than hard-coding hex values in widgets.
class KColors {
  KColors._();

  static const blue = Color(0xFF2C62E0);
  static const blueDark = Color(0xFF1F49B8);
  static const navy = Color(0xFF0E1A3D);
  static const navySoft = Color(0xFF16234A);
  static const paper = Color(0xFFF6F8FC);
  static const paperDim = Color(0xFFEEF1F8);
  static const tint = Color(0xFFEAF0FF);
  static const slate = Color(0xFF4B5568);
  static const slateLight = Color(0xFF8A93A6);
  static const white = Color(0xFFFFFFFF);

  // Accents (style guide: "used inline, not yet tokenized")
  static const accentLight = Color(0xFF8FADFF);
  static const whatsapp = Color(0xFF25D366);
  static const whatsappText = Color(0xFF08331C);

  /// Navy / white overlays, per the style guide's transparency rule.
  static Color navyA(double a) => navy.withValues(alpha: a);
  static Color whiteA(double a) => white.withValues(alpha: a);
}

class KFonts {
  KFonts._();
  static const display = 'SpaceGrotesk';
  static const body = 'Inter';
  static const mono = 'IBMPlexMono';
}

class KText {
  KText._();

  /// Uppercase tracked "eyebrow" label (IBM Plex Mono 500, ~12px).
  static TextStyle eyebrow({Color color = KColors.blue}) =>
      TextStyle(fontFamily: KFonts.mono, fontWeight: FontWeight.w500, fontSize: 12, letterSpacing: 1.6, color: color);

  static TextStyle display(double size, {Color color = KColors.navy, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: KFonts.display, fontWeight: weight, fontSize: size, color: color, height: 1.15);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KColors.blue,
    primary: KColors.blue,
    onPrimary: KColors.white,
    secondary: KColors.navy,
    surface: KColors.white,
    onSurface: KColors.navy,
  );

  TextStyle d(double s, FontWeight w) =>
      TextStyle(fontFamily: KFonts.display, fontSize: s, fontWeight: w, color: KColors.navy);
  TextStyle b(double s, FontWeight w, [Color c = KColors.slate]) =>
      TextStyle(fontFamily: KFonts.body, fontSize: s, fontWeight: w, color: c);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: KFonts.body,
    scaffoldBackgroundColor: KColors.paper,
    textTheme: TextTheme(
      displaySmall: d(36, FontWeight.w700),
      headlineMedium: d(28, FontWeight.w700),
      headlineSmall: d(24, FontWeight.w700),
      titleLarge: d(20, FontWeight.w600),
      titleMedium: d(18, FontWeight.w600),
      titleSmall: b(14, FontWeight.w600, KColors.navy),
      bodyLarge: b(16, FontWeight.w400),
      bodyMedium: b(14, FontWeight.w400),
      bodySmall: b(12, FontWeight.w400, KColors.slateLight),
      labelLarge: b(14, FontWeight.w600, KColors.navy),
      labelMedium: b(12, FontWeight.w500, KColors.slate),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: KColors.navy,
      foregroundColor: KColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: KFonts.display,
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: KColors.white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KColors.blue,
        foregroundColor: KColors.white,
        textStyle: const TextStyle(fontFamily: KFonts.body, fontWeight: FontWeight.w600, fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KColors.navy,
        side: const BorderSide(color: KColors.paperDim, width: 1.5),
        textStyle: const TextStyle(fontFamily: KFonts.body, fontWeight: FontWeight.w600, fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KColors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    snackBarTheme: const SnackBarThemeData(backgroundColor: KColors.navy, behavior: SnackBarBehavior.floating),
    sliderTheme: const SliderThemeData(activeTrackColor: KColors.blue, thumbColor: KColors.blue),
  );
}
