import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens from docs/product/11_DESIGN_SYSTEM.md.
class AppColors {
  AppColors._();
  static const primary = Color(0xFF631D3F); // plum
  static const primaryDark = Color(0xFF4A142E);
  static const primaryLight = Color(0xFF8A3A62);
  // `mint*` names are kept for compatibility; they now hold butter tints.
  static const mint50 = Color(0xFFFFF6CC);
  static const mint100 = Color(0xFFFFEC8E); // butter
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFFFFAEB);
  static const textPrimary = Color(0xFF2B0E1C);
  static const textSecondary = Color(0xFF6D5361);
  static const border = Color(0xFFF0E3C2);
  static const danger = Color(0xFFD93A3A);
  static const dangerDeep = Color(0xFFB3261E);
  static const dangerBg = Color(0xFFFDE8E8);
  static const warning = Color(0xFFF2A23A);
  static const warningBg = Color(0xFFFFF0E0);
  static const skyBg = Color(0xFFE6F0FD);
  static const sky = Color(0xFF2F6FDE);
  static const lavenderBg = Color(0xFFEDE9FB);
  static const lavender = Color(0xFF7B61D9);
}

class AppSpacing {
  AppSpacing._();
  static const screen = 20.0;
  static const cardRadius = 20.0;
  static const tileRadius = 16.0;
  static const pillRadius = 28.0;
}

/// Set to false in tests to avoid runtime font fetching.
bool useGoogleFonts = true;

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.mint100,
      primaryContainer: AppColors.mint100,
      onPrimaryContainer: AppColors.primaryDark,
      secondaryContainer: AppColors.mint100,
      onSecondaryContainer: AppColors.primaryDark,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.background,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  final textTheme = (useGoogleFonts ? GoogleFonts.interTextTheme(base.textTheme) : base.textTheme).copyWith(
    headlineMedium: const TextStyle(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700),
    titleLarge: const TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600),
    titleMedium: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600),
    bodyMedium: const TextStyle(fontSize: 14, height: 20 / 14),
    bodyLarge: const TextStyle(fontSize: 16, height: 22 / 16),
    labelSmall: const TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
  );
  final themedText = (useGoogleFonts ? GoogleFonts.interTextTheme(textTheme) : textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  // Fraunces (a soft serif) for headings — the brand look.
  TextStyle? serif(TextStyle? t) => t == null || !useGoogleFonts ? t : GoogleFonts.fraunces(textStyle: t);
  final brandText = themedText.copyWith(
    headlineMedium: serif(themedText.headlineMedium),
    titleLarge: serif(themedText.titleLarge),
  );

  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.pillRadius));
  return base.copyWith(
    textTheme: brandText,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: brandText.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.mint100,
        minimumSize: const Size.fromHeight(52),
        shape: pill,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: AppColors.primary),
        shape: pill,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.mint50,
      selectedColor: AppColors.mint100,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.mint100,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.mint100,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? AppColors.primaryDark : AppColors.textSecondary)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.mint100 : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
    ),
  );
}
