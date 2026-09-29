import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();

  /// Set to false in tests so no font is fetched over the network.
  static bool useGoogleFonts = true;

  static TextTheme _text(TextTheme base, Color primary, Color secondary) {
    final t = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w400),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
      labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
    ).apply(bodyColor: primary, displayColor: primary);
    final withSecondary = t.copyWith(
      bodySmall: t.bodySmall?.copyWith(color: secondary),
    );
    return useGoogleFonts ? GoogleFonts.interTextTheme(withSecondary) : withSecondary;
  }

  /// [seed] is a white-label tenant's primary colour (§58); null keeps the
  /// CareCompanion green.
  static ThemeData light({Color? seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed ?? AppColors.primary,
      primary: seed ?? AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryLight,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      brightness: Brightness.light,
    );
    return _build(scheme, AppColors.background, AppColors.textPrimary, AppColors.textSecondary,
        AppColors.border, AppColors.mint100);
  }

  static ThemeData dark({Color? seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed ?? AppColors.darkPrimary,
      // A tenant colour is lightened so it stays readable on dark surfaces.
      primary: seed == null ? AppColors.darkPrimary : Color.lerp(seed, Colors.white, 0.35)!,
      onPrimary: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      error: AppColors.danger,
      brightness: Brightness.dark,
    );
    return _build(scheme, AppColors.darkBackground, AppColors.darkText,
        AppColors.darkText.withValues(alpha: 0.7), const Color(0xFF24332D), const Color(0xFF1E3A30));
  }

  static ThemeData _build(ColorScheme scheme, Color bg, Color text, Color text2, Color border,
      Color chip) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: scheme.brightness);
    final textTheme = _text(base.textTheme, text, text2);
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button));
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: text),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: pill,
          side: BorderSide(color: scheme.primary, width: 1.2),
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surface,
        selectedColor: chip,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: textTheme.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: text2,
        indicatorColor: scheme.primary,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.bodyMedium,
        dividerColor: border,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
