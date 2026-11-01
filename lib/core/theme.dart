import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Astra design tokens — "Lyra-style" minimalist dark theme.
/// Dark-only UI, flat surfaces, generous spacing, violet dynamic accent.
/// The Now Playing screen re-tints its own surface dynamically from the
/// album artwork (PaletteGenerator), so accentStatic stays a neutral default.
/// ---------------------------------------------------------------------------
abstract final class AstraTheme {
  static const background = Color(0xFF0B0B10);
  static const surface = Color(0xFF14141C);
  static const surfaceHigh = Color(0xFF1E1E2A);
  static const textPrimary = Color(0xFFF2F2F7);
  static const textSecondary = Color(0xFF9A9AA8);
  static const accentStatic = Color(0xFF8B6CFF);
  static const errorTint = Color(0xFFFF5A79);

  static const radiusL = 20.0;
  static const radiusM = 14.0;
  static const radiusS = 10.0;

  /// Horizontal page padding used across screens.
  static const pagePadding = EdgeInsets.symmetric(horizontal: 20);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accentStatic,
        onPrimary: Colors.white,
        secondary: accentStatic,
        surface: surface,
        error: errorTint,
      ),
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ).copyWith(
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodySmall: const TextStyle(fontSize: 13, color: textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background.withOpacity(0.98),
        indicatorColor: Colors.transparent,
        height: 64,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? textPrimary : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? textPrimary : textSecondary,
            size: 24,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentStatic,
        inactiveTrackColor: textSecondary.withOpacity(0.25),
        thumbColor: textPrimary,
        overlayColor: accentStatic.withOpacity(0.15),
        trackHeight: 3,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogBackgroundColor: surfaceHigh,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
