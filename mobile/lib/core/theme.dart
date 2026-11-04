import 'package:flutter/material.dart';

/// Travel-spa: прохладный морской тон, без dating-purple и «кремовой AI-палитры».
class GlowColors {
  static const ink = Color(0xFF142429);
  static const muted = Color(0xFF5A6B70);
  static const mist = Color(0xFFEFF5F4);
  static const foam = Color(0xFFDCEEEB);
  static const sea = Color(0xFF0F6E6A);
  static const seaDeep = Color(0xFF0A4F4C);
  static const sun = Color(0xFFE8A54B);
  static const coral = Color(0xFFC45C48);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFD5E3E0);
}

class GlowTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: GlowColors.sea,
        onPrimary: Colors.white,
        secondary: GlowColors.sun,
        onSecondary: GlowColors.ink,
        surface: GlowColors.card,
        onSurface: GlowColors.ink,
        error: GlowColors.coral,
      ),
      scaffoldBackgroundColor: GlowColors.mist,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: GlowColors.ink,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: GlowColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: GlowColors.foam,
        selectedColor: GlowColors.sea,
        disabledColor: GlowColors.line,
        labelStyle: const TextStyle(color: GlowColors.ink, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GlowColors.sea,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
