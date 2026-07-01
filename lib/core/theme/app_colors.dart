import 'package:flutter/material.dart';

/// 冷调玻璃拟态（Cool Glassmorphism）色板 —— SchoNavi 视觉令牌单一来源。
///
/// 设计基线：slate 中性 + indigo 主强调 + cyan 数据强调，叠在浅冷渐变背景之上，
/// 玻璃面（frosted glass）承担卡片/输入/抽屉/弹层，长列表卡片保留实心面以保证
/// 可读性与性能。所有颜色在 light/dark 下成对出现，色相一致仅明度切换。
class AppColors {
  AppColors._();

  // ── 墨色 / 文本（slate 家族，冷灰带蓝调）──────────────────────────────
  /// 主文字：slate-900（light）/ slate-50（dark）。
  static const ink = Color(0xFF0F172A);
  static const inkDark = Color(0xFFE2E8F0);

  /// 次文字：slate-600（light）/ slate-400（dark）。满足 4.5:1 对比。
  static const inkSoft = Color(0xFF475569);
  static const inkSoftDark = Color(0xFF94A3B8);

  /// 弱化文字 / 占位：slate-500。
  static const inkFaint = Color(0xFF64748B);

  // ── 面层 / 背景（冷白 + 极浅蓝灰）────────────────────────────────────
  /// 应用底纸：slate-50（light）/ 深 slate（dark）。
  static const paper = Color(0xFFF8FAFC);
  static const paperDark = Color(0xFF0B1120);

  /// 次级面板底：slate-100（light）/ slate-800（dark）。
  static const panel = Color(0xFFF1F5F9);
  static const panelDark = Color(0xFF1E293B);

  /// 卡片实心面：纯白（light）/ slate-800 偏深（dark）。
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF172033);

  // ── 描边 / 分隔（slate-200，冷调细线）────────────────────────────────
  static const line = Color(0xFFE2E8F0);
  static const lineDark = Color(0xFF334155);

  // ── 主强调：indigo（CTA / 聚焦 / 品牌字标）───────────────────────────
  static const indigo = Color(0xFF4F46E5);
  static const indigoPressed = Color(0xFF4338CA);

  /// 浅 indigo 底（图标背板 / 选中底纹 / soft chip）。
  static const indigoSoft = Color(0xFFE0E7FF);
  static const indigoSoftDark = Color(0xFF1E1B4B);

  // ── 数据强调：cyan（数据图 / 链接 / 进度 / 高亮数值）─────────────────
  static const cyan = Color(0xFF0891B2);
  static const cyanBright = Color(0xFF06B6D4);

  /// 浅 cyan 底（match soft / 完成度 / 数据 chip）。
  static const cyanSoft = Color(0xFFCFFAFE);
  static const cyanSoftDark = Color(0xFF083344);

  // ── 语义色 ────────────────────────────────────────────────────────────
  /// 匹配度高（成功 / 完成）：青绿 teal，冷色系内。
  static const match = Color(0xFF0D9488);
  static const matchSoft = Color(0xFFCCFBF1);

  /// 危险 / 限制：冷红 rose，比暖珊瑚克制。
  static const danger = Color(0xFFE11D48);
  static const dangerSoft = Color(0xFFFFE4E6);

  // ── 玻璃面专用（半透明 + 模糊）──────────────────────────────────────
  /// 玻璃面底色：白 72% 透明（light）。需配合 BackdropFilter 模糊才显效。
  static const glassLight = Color(0xB8FFFFFF); // 72%
  static const glassDark = Color(0xA11E293B); // 63%

  /// 玻璃描边：白 60% / 冷白，营造「毛玻璃」高光边。
  static const glassBorderLight = Color(0x99FFFFFF); // 60%
  static const glassBorderDark = Color(0x55CBD5E1); // 35%

  /// 玻璃高光：顶部 1px 内发光，模拟环境光折射。
  static const glassHighlight = Color(0x66FFFFFF);

  // ── 阴影（冷调，蓝灰而非纯黑，更高级）──────────────────────────────
  /// 标准冷阴影：ink @ 8%，偏移 0/2，blur 8。
  static const BoxShadow shadowCool = BoxShadow(
    color: Color(0x14172540),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  /// 抬升冷阴影：ink @ 10%，偏移 0/4，blur 16（浮层/输入条/弹层）。
  static const BoxShadow shadowElevated = BoxShadow(
    color: Color(0x1A172540),
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  /// 玻璃外发光：indigo @ 12%，blur 24，营造柔和发光层次。
  static const BoxShadow shadowGlow = BoxShadow(
    color: Color(0x1F4F46E5),
    blurRadius: 24,
    offset: Offset(0, 6),
  );

  // ── 渐变（背景层 + 品牌强调）──────────────────────────────────────
  /// 应用背景渐变：slate-50 → 极浅 indigo-50，自上而下。让玻璃面的模糊有内容可读。
  static const Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
  );

  static const Gradient backgroundGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B1120), Color(0xFF111827)],
  );

  /// 品牌渐变（indigo → cyan），用于主 CTA / 品牌字标 / 强调胶囊。
  static const Gradient brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF4F46E5), Color(0xFF0891B2)],
  );

  // ── 模糊半径（玻璃面统一）──────────────────────────────────────────
  static const double glassBlur = 18;
  static const double glassBlurStrong = 28;

  // ── 便捷：按明度取色 ────────────────────────────────────────────────
  static Color inkOf(bool isDark) => isDark ? inkDark : ink;
  static Color inkSoftOf(bool isDark) => isDark ? inkSoftDark : inkSoft;
  static Color paperOf(bool isDark) => isDark ? paperDark : paper;
  static Color panelOf(bool isDark) => isDark ? panelDark : panel;
  static Color surfaceOf(bool isDark) => isDark ? surfaceDark : surface;
  static Color lineOf(bool isDark) => isDark ? lineDark : line;
  static Color indigoSoftOf(bool isDark) =>
      isDark ? indigoSoftDark : indigoSoft;
  static Color cyanSoftOf(bool isDark) => isDark ? cyanSoftDark : cyanSoft;
  static Color matchSoftOf(bool isDark) => isDark ? const Color(0xFF134E4A) : matchSoft;
  static Color dangerSoftOf(bool isDark) =>
      isDark ? const Color(0xFF4C0519) : dangerSoft;
  static Color faintOf(bool isDark) =>
      isDark ? inkSoftDark.withValues(alpha: 0.82) : inkFaint;
  static Color glassOf(bool isDark) => isDark ? glassDark : glassLight;
  static Color glassBorderOf(bool isDark) =>
      isDark ? glassBorderDark : glassBorderLight;
}
