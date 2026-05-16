import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark, utilitarian theme for the Payment Bridge admin UI.
class BridgeTheme {
  BridgeTheme._();

  // Colors
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF58A6FF);
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color error = Color(0xFFF85149);
  static const Color textPrimary = Color(0xFFC9D1D9);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          surface: surface,
          error: error,
          onPrimary: Color(0xFF0D1117),
          onSurface: textPrimary,
          onError: Colors.white,
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          const TextTheme(
            headlineLarge: TextStyle(
                color: textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700),
            headlineMedium: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600),
            titleMedium: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500),
            bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
            bodySmall: TextStyle(color: textSecondary, fontSize: 12),
            labelSmall: TextStyle(color: textMuted, fontSize: 10),
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: border, width: 1),
          ),
          elevation: 0,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          elevation: 0,
          titleTextStyle: GoogleFonts.jetBrainsMono(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: const Color(0xFF0D1117),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: primary),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? primary
                  : textMuted),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? primary.withValues(alpha: 0.3)
                  : surfaceLight),
        ),
      );
}
