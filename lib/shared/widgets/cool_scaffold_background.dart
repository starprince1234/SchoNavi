import 'package:flutter/material.dart';

import '../../core/theme/app_surface.dart';

/// 冷调渐变背景层：绘制 [AppSurface.scaffoldGradient]，供玻璃面在其上折射。
///
/// 用法：作为 `Scaffold` body 的最底层（Stack 首子），或用 [wrap] 包裹整个
/// body。玻璃面（[GlassSurface] frosted）依赖下层有内容才显模糊效果，故
/// 凡使用玻璃面的页面都应铺一层本组件。
class CoolScaffoldBackground extends StatelessWidget {
  const CoolScaffoldBackground({super.key, this.child});

  final Widget? child;

  /// 用渐变背景包裹 [content]，常用于直接赋给 `Scaffold.body`。
  static Widget wrap(Widget content) => CoolScaffoldBackground(child: content);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppSurface.of(context).scaffoldGradient,
      ),
      child: child,
    );
  }
}
