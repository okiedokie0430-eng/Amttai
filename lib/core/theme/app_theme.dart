import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: AppColors.primary,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundLight,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundLight,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: _titleLarge.copyWith(color: AppColors.textPrimaryLight),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: _labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: _labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: _labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.error)),
        hintStyle: _bodyMedium.copyWith(color: AppColors.textTertiaryLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.navBarActive,
        unselectedItemColor: AppColors.navBarInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderLight, thickness: 0.5, space: 0),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      textTheme: _textTheme(AppColors.textPrimaryLight),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      dialogTheme: DialogThemeData(elevation: 0, backgroundColor: AppColors.surfaceLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: AppColors.primary,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: _titleLarge.copyWith(color: AppColors.textPrimaryDark),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: _labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primaryLight),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: _labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight, textStyle: _labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.error)),
        hintStyle: _bodyMedium.copyWith(color: AppColors.textTertiaryDark),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.navBarActive,
        unselectedItemColor: AppColors.navBarInactiveDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderDark, thickness: 0.5, space: 0),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      textTheme: _textTheme(AppColors.textPrimaryDark),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      dialogTheme: DialogThemeData(elevation: 0, backgroundColor: AppColors.surfaceDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
    );
  }

  static TextTheme _textTheme(Color c) => TextTheme(
    displayLarge: _displayLarge.copyWith(color: c),
    displayMedium: _displayMedium.copyWith(color: c),
    headlineLarge: _headlineLarge.copyWith(color: c),
    headlineMedium: _headlineMedium.copyWith(color: c),
    titleLarge: _titleLarge.copyWith(color: c),
    titleMedium: _titleMedium.copyWith(color: c),
    titleSmall: _titleSmall.copyWith(color: c),
    bodyLarge: _bodyLarge.copyWith(color: c),
    bodyMedium: _bodyMedium.copyWith(color: c),
    bodySmall: _bodySmall.copyWith(color: c),
    labelLarge: _labelLarge.copyWith(color: c),
    labelMedium: _labelMedium.copyWith(color: c),
    labelSmall: _labelSmall.copyWith(color: c),
  );

  static TextStyle get _displayLarge => GoogleFonts.montserrat(fontSize: 34, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5);
  static TextStyle get _displayMedium => GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5);
  static TextStyle get _headlineLarge => GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.5);
  static TextStyle get _headlineMedium => GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.5);
  static TextStyle get _titleLarge => GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4);
  static TextStyle get _titleMedium => GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get _titleSmall => GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get _bodyLarge => GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5);
  static TextStyle get _bodyMedium => GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500, height: 1.5);
  static TextStyle get _bodySmall => GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, height: 1.5);
  static TextStyle get _labelLarge => GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get _labelMedium => GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get _labelSmall => GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4);
}
