import 'package:flutter/material.dart';
import 'shadcn_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ShadcnColors.background,
      colorScheme: const ColorScheme.dark(
        surface: ShadcnColors.surface,
        primary: ShadcnColors.primary,
        onPrimary: ShadcnColors.primaryForeground,
        secondary: ShadcnColors.card,
        onSecondary: ShadcnColors.foreground,
        error: ShadcnColors.exclude,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: ShadcnColors.foreground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ShadcnColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardTheme(
        color: ShadcnColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ShadcnColors.border, width: 1),
        ),
      ),
    );
  }
}
