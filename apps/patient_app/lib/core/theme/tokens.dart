import 'package:flutter/material.dart';

/// Design tokens from docs/product/11_DESIGN_SYSTEM.md.
class AppColors {
  AppColors._();
  static const primary = Color(0xFF0B5D45);
  static const primaryDark = Color(0xFF08473A);
  static const primaryLight = Color(0xFF1F8A67);
  static const mint50 = Color(0xFFEEF7F2);
  static const mint100 = Color(0xFFDDEFE5);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6FAF8);
  static const textPrimary = Color(0xFF12211B);
  static const textSecondary = Color(0xFF5B6B64);
  static const border = Color(0xFFE3ECE7);
  static const danger = Color(0xFFD93A3A);
  static const dangerBgTop = Color(0xFFB3261E);
  static const dangerBgBottom = Color(0xFF7A1410);
  static const warning = Color(0xFFF2A23A);

  // Accent tiles (background, foreground)
  static const tealBg = Color(0xFFE3F4EF);
  static const tealFg = Color(0xFF1F8A67);
  static const roseBg = Color(0xFFFDE8E8);
  static const roseFg = Color(0xFFE0474C);
  static const lavenderBg = Color(0xFFEDE9FB);
  static const lavenderFg = Color(0xFF7B61D9);
  static const peachBg = Color(0xFFFFF0E0);
  static const peachFg = Color(0xFFF28C28);
  static const skyBg = Color(0xFFE6F0FD);
  static const skyFg = Color(0xFF2F6FDE);

  // Dark
  static const darkBackground = Color(0xFF0E1714);
  static const darkSurface = Color(0xFF16221E);
  static const darkPrimary = Color(0xFF3DBB8C);
  static const darkText = Color(0xFFE6F0EC);
}

class Accent {
  const Accent(this.bg, this.fg);
  final Color bg;
  final Color fg;

  static const teal = Accent(AppColors.tealBg, AppColors.tealFg);
  static const rose = Accent(AppColors.roseBg, AppColors.roseFg);
  static const lavender = Accent(AppColors.lavenderBg, AppColors.lavenderFg);
  static const peach = Accent(AppColors.peachBg, AppColors.peachFg);
  static const sky = Accent(AppColors.skyBg, AppColors.skyFg);
}

class Space {
  Space._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const screen = 20.0;
}

class Radii {
  Radii._();
  static const card = 20.0;
  static const tile = 16.0;
  static const button = 28.0;
  static const input = 28.0;
}

class Shadows {
  Shadows._();
  static const card = [
    BoxShadow(color: Color(0x0F0B5D45), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x330B5D45), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

/// Theme-aware colours for widgets that used to hard-code light-mode tokens.
/// Use these instead of `AppColors.textSecondary`, `Colors.white` surfaces or
/// the pastel `*Bg` tints when the widget shows text on top.
extension CcPalette on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Secondary / caption text (AA contrast on both themes).
  Color get textMuted => isDark ? const Color(0xFFA9B8B1) : AppColors.textSecondary;

  /// Primary body text.
  Color get textStrong => isDark ? AppColors.darkText : AppColors.textPrimary;

  /// Brand colour for text and icons (lighter green in dark mode).
  Color get brand => isDark ? AppColors.darkPrimary : AppColors.primary;

  /// Card / input surface.
  Color get surface => isDark ? AppColors.darkSurface : AppColors.surface;

  Color get borderColor => isDark ? const Color(0xFF24332D) : AppColors.border;

  // Tinted panels that carry text.
  Color get mintSurface => isDark ? const Color(0xFF1E3A30) : AppColors.mint50;
  Color get roseSurface => isDark ? const Color(0xFF3B1F22) : AppColors.roseBg;
  Color get peachSurface => isDark ? const Color(0xFF3B2B18) : AppColors.peachBg;
  Color get lavenderSurface => isDark ? const Color(0xFF2B2542) : AppColors.lavenderBg;
  Color get skySurface => isDark ? const Color(0xFF1B2B42) : AppColors.skyBg;
  Color get tealSurface => isDark ? const Color(0xFF173A30) : AppColors.tealBg;
}
