import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 主题扩展：暴露玻璃面/渐变等无法走 [ColorScheme] 的冷调令牌。
///
/// 用法：`AppSurface.of(context).scaffoldGradient`。在 [AppTheme] 中注册，
/// 与 light/dark 切换时自动 lerp。
@immutable
class AppSurface extends ThemeExtension<AppSurface> {
  const AppSurface({required this.scaffoldGradient, required this.glassBorder});

  final Gradient scaffoldGradient;
  final Color glassBorder;

  static AppSurface of(BuildContext context) {
    final ext = Theme.of(context).extension<AppSurface>();
    if (ext != null) return ext;
    // 兜底：无主题时退回 light 冷渐变。
    return const AppSurface(
      scaffoldGradient: AppColors.backgroundGradient,
      glassBorder: AppColors.glassBorderLight,
    );
  }

  @override
  AppSurface copyWith({Gradient? scaffoldGradient, Color? glassBorder}) =>
      AppSurface(
        scaffoldGradient: scaffoldGradient ?? this.scaffoldGradient,
        glassBorder: glassBorder ?? this.glassBorder,
      );

  @override
  AppSurface lerp(AppSurface? other, double t) {
    if (other == null) return this;
    return AppSurface(
      scaffoldGradient: Gradient.lerp(
        scaffoldGradient,
        other.scaffoldGradient,
        t,
      )!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
    );
  }
}
