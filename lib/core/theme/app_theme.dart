import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.coral,
      brightness: brightness,
    );
    final scheme = base.copyWith(
      primary: isDark ? AppColors.paper : AppColors.ink,
      onPrimary: isDark ? AppColors.ink : AppColors.paper,
      secondary: AppColors.coral,
      onSecondary: Colors.white,
      tertiary: AppColors.match,
      onTertiary: Colors.white,
      surface: isDark ? const Color(0xFF1F1D18) : AppColors.surface,
      onSurface: isDark ? AppColors.paper : AppColors.ink,
      surfaceContainerLowest: isDark
          ? const Color(0xFF151310)
          : AppColors.surface,
      surfaceContainerLow: isDark ? const Color(0xFF1A1814) : AppColors.paper,
      surfaceContainer: isDark ? const Color(0xFF24221C) : AppColors.panel,
      surfaceContainerHighest: isDark
          ? const Color(0xFF2C2922)
          : AppColors.panel,
      outline: isDark ? const Color(0xFF3A352C) : AppColors.line,
      onSurfaceVariant: isDark ? const Color(0xFFBDB5A5) : AppColors.inkSoft,
      error: AppColors.danger,
      onError: Colors.white,
    );
    final onSurface = scheme.onSurface;
    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.05,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.08,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.1,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.5,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.5,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'SourceHanSans',
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF151310)
          : AppColors.paper,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: scheme.onSurface,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'SourceHanSans',
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.onSurface, width: 2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'SourceHanSans',
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.coral,
          textStyle: const TextStyle(
            fontFamily: 'SourceHanSans',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF151310) : AppColors.paper,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'SourceHanSans',
          fontWeight: FontWeight.w900,
          fontSize: 20,
          letterSpacing: 0,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        indicatorColor: AppColors.coralSoft,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'SourceHanSans',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.coral, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line),
    );
  }
}
