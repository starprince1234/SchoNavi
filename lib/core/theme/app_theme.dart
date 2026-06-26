import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_surface.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      brightness: brightness,
    );
    final scheme = base.copyWith(
      primary: AppColors.indigo,
      onPrimary: Colors.white,
      secondary: AppColors.cyan,
      onSecondary: Colors.white,
      tertiary: AppColors.match,
      onTertiary: Colors.white,
      // primaryContainer：用户气泡（浅 indigo）。onPrimaryContainer 保持深墨。
      primaryContainer: isDark ? AppColors.indigoSoftDark : AppColors.indigoSoft,
      onPrimaryContainer: isDark ? AppColors.inkDark : AppColors.indigoPressed,
      // secondaryContainer：助手气泡（极浅冷灰），区分用户气泡。
      secondaryContainer:
          isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
      onSecondaryContainer: isDark ? AppColors.inkDark : AppColors.ink,
      surface: AppColors.surfaceOf(isDark),
      onSurface: AppColors.inkOf(isDark),
      surfaceContainerLowest:
          isDark ? const Color(0xFF0B1120) : AppColors.surface,
      surfaceContainerLow:
          isDark ? const Color(0xFF111827) : AppColors.paper,
      surfaceContainer:
          isDark ? AppColors.panelDark : AppColors.panel,
      surfaceContainerHighest:
          isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      outline: AppColors.lineOf(isDark),
      onSurfaceVariant: AppColors.inkSoftOf(isDark),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerSoft,
      onErrorContainer: AppColors.danger,
    );
    final onSurface = scheme.onSurface;
    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.02,
        height: 1.05,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.02,
        height: 1.08,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.01,
        height: 1.1,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.01,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.01,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.01,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.005,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.005,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.55,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.55,
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
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      // scaffold 用冷渐变作底，玻璃面才有内容可模糊折射。
      scaffoldBackgroundColor: AppColors.paperOf(isDark),
      textTheme: textTheme,
      extensions: [
        AppSurface(
          scaffoldGradient:
              isDark ? AppColors.backgroundGradientDark : AppColors.backgroundGradient,
          glassBorder: AppColors.glassBorderOf(isDark),
        ),
      ],
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
          backgroundColor: AppColors.indigo,
          foregroundColor: Colors.white,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
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
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
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
          foregroundColor: AppColors.indigo,
          textStyle: const TextStyle(
            fontFamily: 'SourceHanSans',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'SourceHanSans',
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.01,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.indigoSoft,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 64,
        labelTextStyle: const WidgetStatePropertyAll(
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
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
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
          borderSide: const BorderSide(color: AppColors.indigo, width: 2),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          color: AppColors.paper,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.indigo,
        linearTrackColor: AppColors.line,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const StadiumBorder(),
      ),
    );
  }
}

