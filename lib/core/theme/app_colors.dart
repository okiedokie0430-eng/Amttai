import 'package:flutter/material.dart';

/// Centralised colour palette - light & dark modes.
///
/// iOS 26 aesthetics: vibrant, frosted, no shadows, rounded, translucent.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF9A6C);
  static const Color primaryDark = Color(0xFFE55A2B);

  // Accent
  static const Color accent = Color(0xFF2EC4B6);
  static const Color accentLight = Color(0xFF6EE7DB);

  // Light Neutrals
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceVariantLight = Color(0xFFF1F3F5);
  static const Color borderLight = Color(0xFFE9ECEF);

  // Dark Neutrals
  static const Color backgroundDark = Color(0xFF0F0F0F);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color surfaceVariantDark = Color(0xFF2C2C2E);
  static const Color borderDark = Color(0xFF3A3A3C);

  // Text Light
  static const Color textPrimaryLight = Color(0xFF212529);
  static const Color textSecondaryLight = Color(0xFF6C757D);
  static const Color textTertiaryLight = Color(0xFFADB5BD);

  // Text Dark
  static const Color textPrimaryDark = Color(0xFFF2F2F7);
  static const Color textSecondaryDark = Color(0xFF98989F);
  static const Color textTertiaryDark = Color(0xFF636366);

  static const Color textOnPrimary = Colors.white;

  // Semantic
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFFCC02);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF007AFF);

  // Premium
  static const Color premiumGold = Color(0xFFFFD43B);
  static const Color premiumGradientStart = Color(0xFFFF6B35);
  static const Color premiumGradientEnd = Color(0xFFFF9A6C);

  // Nav bar frosted glass
  static const Color navBarGlassLight = Color(0xDDF8F9FA);
  static const Color navBarGlassDark = Color(0xDD1C1C1E);
  static const Color navBarActive = Color(0xFFFF6B35);
  static const Color navBarInactive = Color(0xFFADB5BD);
  static const Color navBarInactiveDark = Color(0xFF8E8E93);

  // Card overlay frosted glass
  static const Color glassWhiteLight = Color(0xBBFFFFFF);
  static const Color glassWhiteDark = Color(0xBB1C1C1E);
  static const Color glassBorder = Color(0x33FFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [premiumGradientStart, premiumGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Adaptive helpers
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? backgroundDark : backgroundLight;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceDark : surfaceLight;

  static Color surfaceVariant(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceVariantDark : surfaceVariantLight;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? borderDark : borderLight;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textSecondaryDark : textSecondaryLight;

  static Color textTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textTertiaryDark : textTertiaryLight;

  static Color navBarGlass(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? navBarGlassDark : navBarGlassLight;

  static Color glassWhite(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? glassWhiteDark : glassWhiteLight;
}
