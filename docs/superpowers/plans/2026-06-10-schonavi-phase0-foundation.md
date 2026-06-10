# SchoNavi Phase 0 · 视觉与交互地基 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 SchoNavi 的视觉与基础交互从默认 Material 升级为「Bento 编辑感 · 克制」识别系统（色彩/黑体/磁贴/动效/触觉），且不破坏现有功能与测试。

**Architecture:** 绝大多数视觉通过重写 `core/theme/app_theme.dart`（`ColorScheme` + `TextTheme` + 组件主题）一次性铺到全 App；自定义组件（卡片/三态/标签）做保结构的轻量 restyle；新增 `Haptics`、`AppBottomSheet`、`BentoTile`、`StatTile`、`Skeleton`、`SectionHeader` 复用件与共享轴页面转场。**严格保持 `app_e2e_test.dart` 与 `shared_widgets_test.dart` 全绿**（卡片仍为 `Card`、底栏文案、tooltip、`重试/修改条件`、`张三`/`高` 等断言不变）。

**Tech Stack:** Flutter（Material 3）· Riverpod 3 · go_router 17 · 思源黑体/Noto Sans SC 字体资源。

**Spec:** `docs/superpowers/specs/2026-06-10-schonavi-bento-enhancement-design.md` §3、§4.1。

**约定提醒:** 包名 `scho_navi`；`lib` 内用相对 import，测试用 `package:scho_navi/...`；TDD、频繁提交；命令在仓库根 `D:/Androidprj/AIGC-LXJH/scho_navi` 下执行（bash）。

---

## File Structure

- Create `lib/core/theme/app_colors.dart` — 颜色 tokens（唯一色值来源）。
- Modify `lib/core/theme/app_theme.dart` — Bento `ThemeData`（light/dark）。
- Modify `pubspec.yaml` — 注册字体；Create `assets/fonts/` — 字体文件。
- Create `lib/core/haptics/haptics.dart` — 触觉封装；Test `test/core/haptics/haptics_test.dart`。
- Create `lib/core/ui/app_bottom_sheet.dart` — 统一底部抽屉（拖拽手柄 + 下滑关闭）。
- Create `lib/core/motion/page_transition.dart` — 共享轴转场（GoRouter 用）。
- Create `lib/shared/widgets/bento_tile.dart`、`stat_tile.dart`、`skeleton.dart`、`section_header.dart`（+ 对应 widget 测试）。
- Modify `lib/shared/widgets/{professor_card,field_chips,match_level_chip,loading_view,error_view,empty_view}.dart` — 保结构 restyle。
- Modify `lib/core/router/app_router.dart`、`lib/features/professor/pages/professor_page.dart` — Hero + 转场接线。

---

## Task 1: 字体资源与 pubspec 注册

**Files:**
- Create: `assets/fonts/NotoSansSC-Medium.ttf`, `assets/fonts/NotoSansSC-Black.ttf`
- Modify: `pubspec.yaml`

- [ ] **Step 1: 获取字体文件**

下载 **Noto Sans SC（= 思源黑体）** 的两个静态字重并放入 `assets/fonts/`：
- 打开 https://fonts.google.com/noto/specimen/Noto+Sans+SC → "Get font" / "Download all" → 解压后取静态实例 `NotoSansSC-Medium.ttf`（500）与 `NotoSansSC-Black.ttf`（900）。
- 备选来源：https://github.com/notofonts/noto-cjk（Sans）→ 取 Medium/Black。
- 仅放这两个字重（控制 APK 体积，spec §3.2）。文件名须与上面完全一致。

> 若暂时拿不到字体：仍继续后续任务，`ThemeData(fontFamily: 'SourceHanSans')` 在缺字体时会自动回退系统字体并合成粗体，App 不会崩溃；补上字体后即生效。

- [ ] **Step 2: 在 pubspec 注册字体与 assets**

修改 `pubspec.yaml`，在 `flutter:` 段（`uses-material-design: true` 之后）加入：

```yaml
  assets:
    - assets/fonts/

  fonts:
    - family: SourceHanSans
      fonts:
        - asset: assets/fonts/NotoSansSC-Medium.ttf
          weight: 500
        - asset: assets/fonts/NotoSansSC-Black.ttf
          weight: 900
```

- [ ] **Step 3: 拉取依赖并校验**

Run: `flutter pub get`
Expected: 成功，无报错。

Run: `flutter analyze`
Expected: `No issues found!`（字体尚未被引用，仅校验 pubspec 合法）。

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml assets/fonts/
git commit -m "chore: bundle Source Han Sans (Noto Sans SC) Medium+Black fonts"
```

---

## Task 2: 颜色 tokens + Bento 主题重写

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: 写颜色 tokens**

创建 `lib/core/theme/app_colors.dart`：

```dart
import 'package:flutter/material.dart';

/// Bento 编辑感 · 克制 配色 tokens（spec §3.1）。全 App 唯一色值来源。
class AppColors {
  AppColors._();

  static const ink = Color(0xFF1A1814); // 墨黑：文字/描边/英雄底/主按钮
  static const paper = Color(0xFFFBF8F1); // 奶油底：页面背景
  static const panel = Color(0xFFF3EFE4); // 浅面板：次级磁贴/输入底
  static const surface = Color(0xFFFFFFFF); // 白：卡片磁贴
  static const coral = Color(0xFFFF5A3D); // 珊瑚橘：主强调
  static const coralSoft = Color(0xFFFBEDE9); // 珊瑚浅底
  static const lime = Color(0xFFD8ED57); // 柠檬黄：仅英雄大数字
  static const match = Color(0xFF2FA36B); // 匹配绿
  static const matchSoft = Color(0xFFE7F4EC);
  static const line = Color(0xFFE4DECE); // 描边/分隔
  static const inkSoft = Color(0xFF8A8578); // 次要文字
  static const danger = Color(0xFFB5562B); // 差距/错误（暖砖）
}
```

- [ ] **Step 2: 重写 AppTheme**

整体替换 `lib/core/theme/app_theme.dart`：

```dart
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
      surfaceContainerLowest: isDark ? const Color(0xFF151310) : AppColors.surface,
      surfaceContainerLow: isDark ? const Color(0xFF1A1814) : AppColors.paper,
      surfaceContainer: isDark ? const Color(0xFF24221C) : AppColors.panel,
      surfaceContainerHighest: isDark ? const Color(0xFF2C2922) : AppColors.panel,
      outline: AppColors.line,
      onSurfaceVariant: AppColors.inkSoft,
      error: AppColors.danger,
      onError: Colors.white,
    );
    final onSurface = scheme.onSurface;

    final textTheme = TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1, height: 1.05, color: onSurface),
      displayMedium: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.5, height: 1.08, color: onSurface),
      displaySmall: TextStyle(fontWeight: FontWeight.w900, height: 1.1, color: onSurface),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: onSurface),
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: onSurface),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: onSurface),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
      titleSmall: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
      bodyLarge: TextStyle(fontWeight: FontWeight.w500, height: 1.5, color: onSurface),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500, height: 1.5, color: onSurface),
      bodySmall: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
      labelLarge: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
      labelMedium: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
      labelSmall: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'SourceHanSans',
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF151310) : AppColors.paper,
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
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: scheme.onSurface),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontFamily: 'SourceHanSans', fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.onSurface, width: 2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontFamily: 'SourceHanSans', fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.coral,
          textStyle: const TextStyle(fontFamily: 'SourceHanSans', fontWeight: FontWeight.w700),
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
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: AppColors.coralSoft,
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'SourceHanSans', fontWeight: FontWeight.w700, fontSize: 12),
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
```

- [ ] **Step 3: 校验编译与现有回归全绿**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: 全部通过（主题改色不改结构，`app_e2e_test`/`shared_widgets_test` 仍绿）。

- [ ] **Step 4: Commit**

```bash
git add lib/core/theme/app_colors.dart lib/core/theme/app_theme.dart
git commit -m "feat(theme): Bento color tokens and heavy-type Material theme"
```

---

## Task 3: 触觉封装 + 统一底部抽屉

**Files:**
- Create: `lib/core/haptics/haptics.dart`, `lib/core/ui/app_bottom_sheet.dart`
- Test: `test/core/haptics/haptics_test.dart`

- [ ] **Step 1: 写失败测试（触觉调用平台通道）**

创建 `test/core/haptics/haptics_test.dart`：

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/haptics/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Haptics.selection 触发 HapticFeedback 平台调用', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });

    Haptics.selection();
    await Future<void>.delayed(Duration.zero);

    expect(
      calls.where((c) => c.method == 'HapticFeedback.vibrate'),
      isNotEmpty,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/haptics/haptics_test.dart`
Expected: FAIL（`haptics.dart` 不存在 / `Haptics` 未定义）。

- [ ] **Step 3: 实现 Haptics 与 AppBottomSheet**

创建 `lib/core/haptics/haptics.dart`：

```dart
import 'package:flutter/services.dart';

/// 统一触觉反馈入口（spec §4.1）。
class Haptics {
  Haptics._();

  /// 选中/切 tab/点 chip。
  static void selection() => HapticFeedback.selectionClick();

  /// 普通按钮/收藏。
  static void light() => HapticFeedback.lightImpact();

  /// 重要完成（分析/生成完成）。
  static void medium() => HapticFeedback.mediumImpact();

  /// 错误。
  static void error() => HapticFeedback.vibrate();
}
```

创建 `lib/core/ui/app_bottom_sheet.dart`：

```dart
import 'package:flutter/material.dart';

/// 统一底部抽屉：拖拽手柄 + 下滑关闭 + 键盘避让（spec §4.1）。
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool expand = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: expand
          ? FractionallySizedBox(heightFactor: 0.9, child: builder(ctx))
          : builder(ctx),
    ),
  );
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/core/haptics/haptics_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/core/haptics/haptics.dart lib/core/ui/app_bottom_sheet.dart test/core/haptics/haptics_test.dart
git commit -m "feat(core): Haptics helper and unified bottom sheet"
```

---

## Task 4: BentoTile + StatTile（大数字滚动）

**Files:**
- Create: `lib/shared/widgets/bento_tile.dart`, `lib/shared/widgets/stat_tile.dart`
- Test: `test/shared/widgets/bento_widgets_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/shared/widgets/bento_widgets_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/bento_tile.dart';
import 'package:scho_navi/shared/widgets/stat_tile.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('StatTile 动画结束后显示目标数字与标签', (tester) async {
    await tester.pumpWidget(_wrap(const StatTile(value: 83, label: '契合度')));
    await tester.pumpAndSettle();
    expect(find.text('83'), findsOneWidget);
    expect(find.text('契合度'), findsOneWidget);
  });

  testWidgets('BentoTile onTap 回调被触发', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(BentoTile(onTap: () => tapped = true, child: const Text('块'))),
    );
    await tester.tap(find.text('块'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/shared/widgets/bento_widgets_test.dart`
Expected: FAIL（两个文件未定义）。

- [ ] **Step 3: 实现 BentoTile 与 StatTile**

创建 `lib/shared/widgets/bento_tile.dart`：

```dart
import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';

/// Bento 磁贴：圆角面板 + 可选点按（按压回弹 + 触觉）。
class BentoTile extends StatefulWidget {
  const BentoTile({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(14),
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;

  @override
  State<BentoTile> createState() => _BentoTileState();
}

class _BentoTileState extends State<BentoTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = AnimatedScale(
      scale: _down ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: widget.border,
        ),
        child: widget.child,
      ),
    );
    if (widget.onTap == null) return tile;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        Haptics.light();
        widget.onTap!();
      },
      child: tile,
    );
  }
}
```

创建 `lib/shared/widgets/stat_tile.dart`：

```dart
import 'package:flutter/material.dart';

/// 大数字统计块：0 → value 滚动动画（spec §3.4）。
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;
  final String label;
  final Color? color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numColor = color ?? theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            '$v',
            style: theme.textTheme.displaySmall?.copyWith(color: numColor),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/shared/widgets/bento_widgets_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/bento_tile.dart lib/shared/widgets/stat_tile.dart test/shared/widgets/bento_widgets_test.dart
git commit -m "feat(widgets): BentoTile and animated StatTile"
```

---

## Task 5: SectionHeader + restyle FieldChips / MatchLevelChip

**Files:**
- Create: `lib/shared/widgets/section_header.dart`
- Modify: `lib/shared/widgets/field_chips.dart`, `lib/shared/widgets/match_level_chip.dart`

> 保持断言：`MatchLevelChip` 文案仍含「高」（`shared_widgets_test.dart` line 49）；`FieldChips` 空列表仍渲染「暂无信息」。

- [ ] **Step 1: 写 SectionHeader**

创建 `lib/shared/widgets/section_header.dart`：

```dart
import 'package:flutter/material.dart';

/// 区块标题：粗黑体 + 可选珊瑚色前导竖条。
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.accent = true});

  final String title;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (accent) ...[
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(title, style: theme.textTheme.titleLarge),
      ],
    );
  }
}
```

- [ ] **Step 2: restyle MatchLevelChip（保留「匹配度：X」含「高」）**

整体替换 `lib/shared/widgets/match_level_chip.dart`：

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/match_level.dart';

class MatchLevelChip extends StatelessWidget {
  const MatchLevelChip({super.key, required this.level});

  final MatchLevel level;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (level) {
      MatchLevel.high => (AppColors.ink, AppColors.paper),
      MatchLevel.medium => (AppColors.coralSoft, AppColors.coral),
      MatchLevel.low => (AppColors.panel, AppColors.inkSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '匹配度：${level.label}',
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}
```

- [ ] **Step 3: restyle FieldChips（保留「暂无信息」空态）**

整体替换 `lib/shared/widgets/field_chips.dart`：

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FieldChips extends StatelessWidget {
  const FieldChips({super.key, required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const Text('暂无信息');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: fields
          .map(
            (f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
```

- [ ] **Step 4: 运行受影响测试**

Run: `flutter test test/shared/widgets/shared_widgets_test.dart`
Expected: PASS（`MatchLevelChip` 仍含「高」）。

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/section_header.dart lib/shared/widgets/field_chips.dart lib/shared/widgets/match_level_chip.dart
git commit -m "feat(widgets): SectionHeader and Bento restyle of chips"
```

---

## Task 6: restyle ProfessorCard（保结构）

**Files:**
- Modify: `lib/shared/widgets/professor_card.dart`

> 必须保留：根为 `Card`（`app_e2e_test` `find.byType(Card)`）；`r.name` 独立 `Text`（`find.text('张三')`）；university 文案；收藏 tooltip「收藏导师」/「取消收藏」；`onTap`。

- [ ] **Step 1: 整体替换 professor_card.dart**

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/recommendation.dart';
import 'field_chips.dart';
import 'match_level_chip.dart';

class ProfessorCard extends StatelessWidget {
  const ProfessorCard({
    super.key,
    required this.recommendation,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoritePressed,
    this.onOpenHomepagePressed,
  });

  final Recommendation recommendation;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onOpenHomepagePressed;

  @override
  Widget build(BuildContext context) {
    final r = recommendation;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.coral),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name, style: theme.textTheme.titleLarge),
                                const SizedBox(height: 2),
                                Text(r.title, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          MatchLevelChip(level: r.matchLevel),
                          if (onFavoritePressed != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: isFavorite ? '取消收藏' : '收藏导师',
                              icon: Icon(
                                isFavorite ? Icons.bookmark : Icons.bookmark_border,
                              ),
                              onPressed: onFavoritePressed,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${r.university} / ${r.college}', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 10),
                      FieldChips(fields: r.researchFields),
                      const SizedBox(height: 10),
                      Text(
                        '推荐理由：${r.reason}',
                        style: theme.textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (onOpenHomepagePressed != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onOpenHomepagePressed,
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('访问主页'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行受影响测试**

Run: `flutter test test/shared/widgets/shared_widgets_test.dart test/app_e2e_test.dart`
Expected: PASS（`Card`、`张三`、university、onTap、tooltip 均满足）。

- [ ] **Step 3: Commit**

```bash
git add lib/shared/widgets/professor_card.dart
git commit -m "feat(widgets): Bento restyle ProfessorCard with coral accent"
```

---

## Task 7: 品牌化三态 + 骨架屏

**Files:**
- Create: `lib/shared/widgets/skeleton.dart`
- Modify: `lib/shared/widgets/loading_view.dart`, `lib/shared/widgets/error_view.dart`, `lib/shared/widgets/empty_view.dart`

> 保持断言：`LoadingView` 仍含 `CircularProgressIndicator`；`ErrorView` 仍有「重试」且回调；`EmptyView` 仍有 `actionLabel` 且回调。

- [ ] **Step 1: 写 Skeleton（带闪烁动画）**

创建 `lib/shared/widgets/skeleton.dart`：

```dart
import 'package:flutter/material.dart';

/// 骨架占位：循环淡入淡出。列表加载用。
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width = double.infinity, this.radius = 8});

  final double height;
  final double width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}
```

- [ ] **Step 2: restyle LoadingView（保留 CircularProgressIndicator）**

整体替换 `lib/shared/widgets/loading_view.dart`：

```dart
import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.secondary),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(label!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: restyle ErrorView（保留「重试」+ 回调）**

整体替换 `lib/shared/widgets/error_view.dart`：

```dart
import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_dissatisfied_outlined, size: 52, color: theme.colorScheme.error),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: restyle EmptyView（保留 actionLabel + 回调）**

整体替换 `lib/shared/widgets/empty_view.dart`：

```dart
import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_outlined, size: 52, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 运行受影响测试**

Run: `flutter test test/shared/widgets/shared_widgets_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/skeleton.dart lib/shared/widgets/loading_view.dart lib/shared/widgets/error_view.dart lib/shared/widgets/empty_view.dart
git commit -m "feat(widgets): branded loading/error/empty states and Skeleton"
```

---

## Task 8: 共享轴页面转场 + 卡片→详情 Hero

**Files:**
- Create: `lib/core/motion/page_transition.dart`
- Modify: `lib/core/router/app_router.dart`, `lib/features/professor/pages/professor_page.dart`, `lib/shared/widgets/professor_card.dart`

- [ ] **Step 1: 写转场辅助**

创建 `lib/core/motion/page_transition.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 共享轴（横向）转场：淡入 + 轻微右移。GoRouter 用。
CustomTransitionPage<void> sharedAxisPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
```

- [ ] **Step 2: 在 router 用 pageBuilder（shell 外路由套转场）**

整体替换 `lib/core/router/app_router.dart`（shell 内三 tab 保持 `builder` 无转场；其余 6 条路由改 `pageBuilder` 套 `sharedAxisPage`）：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/pages/chat_page.dart';
import '../../features/compare/pages/compare_page.dart';
import '../../features/email/pages/email_page.dart';
import '../../features/favorite/pages/favorite_page.dart';
import '../../features/history/pages/history_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/match/pages/match_page.dart';
import '../../features/professor/pages/professor_page.dart';
import '../../features/recommendation/pages/recommendation_page.dart';
import '../../shared/widgets/scaffold_with_bottom_nav.dart';
import '../motion/page_transition.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            ScaffoldWithBottomNav(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomePage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/favorites', builder: (_, _) => const FavoritePage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/history', builder: (_, _) => const HistoryPage())],
          ),
        ],
      ),
      GoRoute(
        path: '/recommendation',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: RecommendationPage(prompt: state.uri.queryParameters['q'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/professor/:id',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: ProfessorPage(professorId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/chat',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: ChatPage(
            sessionId: state.uri.queryParameters['sid'] ?? '',
            professorId: state.uri.queryParameters['pid'],
          ),
        ),
      ),
      GoRoute(
        path: '/email',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: EmailPage(professorId: state.uri.queryParameters['pid'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/compare',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: ComparePage(
            ids: (state.uri.queryParameters['ids'] ?? '')
                .split(',')
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty)
                .toList(),
          ),
        ),
      ),
      GoRoute(
        path: '/match',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: MatchPage(professorId: state.uri.queryParameters['pid'] ?? ''),
        ),
      ),
    ],
  );
});
```

- [ ] **Step 3: 加 Hero（卡片→详情共享标题）**

在 `lib/shared/widgets/professor_card.dart` 的姓名 `Text(r.name, ...)` 外包 `Hero`：

```dart
Hero(
  tag: 'prof-name-${r.professorId}',
  child: Material(
    type: MaterialType.transparency,
    child: Text(r.name, style: theme.textTheme.titleLarge),
  ),
),
```

在 `lib/features/professor/pages/professor_page.dart` 的详情标题处（`_Detail.build` 中 `'${p.name}  ${p.title}'` 那个 `Text`）改为以姓名为 Hero：

```dart
Expanded(
  child: Hero(
    tag: 'prof-name-${p.id}',
    child: Material(
      type: MaterialType.transparency,
      child: Text('${p.name}  ${p.title}', style: textTheme.headlineSmall),
    ),
  ),
),
```

> Hero tag 用 `professorId`，两端一致即可触发共享元素动画；`Material(transparency)` 避免飞行途中文字底色异常。

- [ ] **Step 4: 校验全套测试 + 分析**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: 全绿（`app_e2e_test` 导航仍通：转场不改路由结构/文案）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/motion/page_transition.dart lib/core/router/app_router.dart lib/features/professor/pages/professor_page.dart lib/shared/widgets/professor_card.dart
git commit -m "feat(motion): shared-axis page transitions and card->detail Hero"
```

---

## Task 9: 收口校验 + 手动冒烟

**Files:** 无新增（验收任务）。

- [ ] **Step 1: 全量静态检查**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: 全部通过。

- [ ] **Step 3: 手动冒烟（mock 模式）**

Run: `flutter run`（或 VS Code “SchoNavi Flutter (mock)”）
人工确认（spec §3/§4 视觉与交互）：
- 首页奶油底、黑体标题、珊瑚「开始推荐」pill；输入→推荐结果卡片为珊瑚左条 Bento 卡。
- 点卡片有共享轴转场 + 姓名 Hero 飞入；详情页底栏按钮 pill 化。
- 底栏「首页/收藏/历史」珊瑚选中态；收藏切换有触觉（真机）。
- 三态：加载珊瑚转圈、空/错态品牌化。
- 暗色模式（系统切换）墨底奶油字不崩。

- [ ] **Step 4: 收口提交（若冒烟有零碎修整）**

```bash
git add -A
git commit -m "chore: Phase 0 visual & interaction foundation smoke fixes"
```

> 若无修整可跳过本提交。Phase 0 完成后，全 App 已是 Bento 外观且回归全绿，可进入 Phase 1（匹配雷达）。
