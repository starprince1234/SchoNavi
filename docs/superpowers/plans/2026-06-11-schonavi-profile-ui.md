# SchoNavi 个人档案界面（原子组件 + 向导/中心 + 触发/打磨）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在「引擎」计划之上交付用户可见的档案录入闭环——原子化组件 + 首填向导(B) + 档案中心(C) + 即时触发，端到端打通"背景换更准推荐"。

**Architecture:** atoms/molecules 放 `shared/widgets`（通用）与 `features/profile/widgets`（档案专属）；organisms/pages 放 `features/profile`。向导与中心**复用同一批 organism**（构造参数 `value: UserProfile` + 回调 `onChanged`）。状态读写经引擎计划的 `profileProvider`。

**Tech Stack:** Flutter Material 3 + Bento `AppColors`/`Haptics`/`BentoTile`/`AnimatedEntrance`/`ShimmerSkeleton`，go_router，flutter_riverpod。

**前置：** 「引擎计划」(`2026-06-11-schonavi-profile-engine.md`) 已完成（`UserProfile` 扩展、`profileProvider`、抽取仓储、推荐注入均就位）。对应 spec Phase D/E/F。

**全程约定：** 先写 widget 失败测试 → 跑红 → 实现 → 跑绿 → commit。`flutter test` / `flutter analyze` 全程绿。Widget 测脚手架统一用 `MaterialApp(home: ...)` 或 `MaterialApp.router`（需路由时），Riverpod 用 `ProviderScope`/`UncontrolledProviderScope`。

---

## 文件结构（本计划新增/改动）

**新增 atoms（`lib/shared/widgets/`）**：`labeled_text_field.dart`、`choice_chip_group.dart`、`step_dots.dart`、`completion_ring.dart`。
**新增 molecules（`lib/features/profile/widgets/`）**：`gpa_field.dart`、`achievement_item_card.dart`、`profile_section_tile.dart`、`wizard_scaffold.dart`。
**新增 organisms（`lib/features/profile/widgets/`）**：`basic_info_form.dart`、`score_and_interests_form.dart`、`achievements_editor.dart`、`profile_summary_header.dart`、`profile_prompt_sheet.dart`。
**新增 providers/pages（`lib/features/profile/`）**：`providers/achievements_extraction_provider.dart`、`pages/profile_wizard_page.dart`、`pages/profile_page.dart`。
**改动**：`lib/core/router/app_router.dart`（+`/profile`、`/profile/wizard`）、`lib/features/home/pages/home_page.dart`（档案入口 + 即时触发）、`lib/features/settings/pages/settings_page.dart`（入口 + 隐私行）、`lib/features/email/pages/email_page.dart` 与 `lib/features/email/widgets/profile_sheet.dart`（并入新流，读 `profileProvider`）。
**测试**：每个 widget/page 一份 `test/...`。

---

## Phase D · 原子 & 分子组件

### Task D1：LabeledTextField（atom）

**Files:** Create `lib/shared/widgets/labeled_text_field.dart`；Test `test/shared/widgets/labeled_text_field_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/labeled_text_field.dart';

void main() {
  testWidgets('显示 label 与初值，输入触发 onChanged', (tester) async {
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabeledTextField(
            label: '姓名',
            initialValue: '张三',
            onChanged: (v) => changed = v,
          ),
        ),
      ),
    );

    expect(find.text('姓名'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '李四');
    expect(changed, '李四');
  });
}
```

- [ ] **Step 2：跑测试确认失败** — Run: `flutter test test/shared/widgets/labeled_text_field_test.dart` → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 带标签的文本输入原子：标签 + 圆角输入框。受控初值 + onChanged 回调。
class LabeledTextField extends StatefulWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
    this.fieldKey,
  });

  final String label;
  final ValueChanged<String> onChanged;
  final String? initialValue;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;
  final Key? fieldKey;

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        TextField(
          key: widget.fieldKey,
          controller: _controller,
          onChanged: widget.onChanged,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            fillColor: AppColors.surface,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.coral, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4：跑测试确认通过** — Run: `flutter test test/shared/widgets/labeled_text_field_test.dart` → PASS。
- [ ] **Step 5：Commit** — `git add lib/shared/widgets/labeled_text_field.dart test/shared/widgets/labeled_text_field_test.dart && git commit -m "feat(ui): LabeledTextField atom"`

---

### Task D2：ChoiceChipGroup（atom，泛型单选）

**Files:** Create `lib/shared/widgets/choice_chip_group.dart`；Test `test/shared/widgets/choice_chip_group_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/choice_chip_group.dart';

void main() {
  testWidgets('点选某项回调其值', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChoiceChipGroup<String>(
            options: const [('m', '男'), ('f', '女')],
            selected: 'm',
            onSelected: (v) => picked = v,
          ),
        ),
      ),
    );

    expect(find.text('男'), findsOneWidget);
    await tester.tap(find.text('女'));
    expect(picked, 'f');
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';

/// 泛型单选 chip 组。options 为 (值, 显示文案) 列表。
class ChoiceChipGroup<T> extends StatelessWidget {
  const ChoiceChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          _Chip(
            label: label,
            active: value == selected,
            onTap: () {
              Haptics.selection();
              onSelected(value);
            },
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.ink : AppColors.line,
            width: active ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.paper : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(ui): ChoiceChipGroup atom (generic single-select)"`

---

### Task D3：StepDots（atom）

**Files:** Create `lib/shared/widgets/step_dots.dart`；Test `test/shared/widgets/step_dots_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/step_dots.dart';

void main() {
  testWidgets('渲染 count 个圆点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StepDots(count: 3, index: 1))),
    );
    expect(find.byKey(const Key('step-dot')), findsNWidgets(3));
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 向导进度点：当前项加宽并用珊瑚色。
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            key: const Key('step-dot'),
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 6),
            width: i == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? AppColors.coral : AppColors.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(ui): StepDots atom"`

---

### Task D4：CompletionRing（atom，0→value 动画）

**Files:** Create `lib/shared/widgets/completion_ring.dart`；Test `test/shared/widgets/completion_ring_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/completion_ring.dart';

void main() {
  testWidgets('显示百分比文案', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CompletionRing(value: 0.86))),
    );
    await tester.pumpAndSettle();
    expect(find.text('86%'), findsOneWidget);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 完成度环：0→value 动画 + 中心百分比。
class CompletionRing extends StatelessWidget {
  const CompletionRing({
    super.key,
    required this.value, // 0.0–1.0
    this.size = 56,
    this.ringColor = AppColors.lime,
    this.trackColor = const Color(0x33FFFFFF),
    this.textColor = AppColors.lime,
  });

  final double value;
  final double size;
  final Color ringColor;
  final Color trackColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
            Text(
              '${(v * 100).round()}%',
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(ui): CompletionRing atom (animated)"`

---

### Task D5：GpaField（molecule）

**Files:** Create `lib/features/profile/widgets/gpa_field.dart`；Test `test/features/profile/widgets/gpa_field_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';
import 'package:scho_navi/features/profile/widgets/gpa_field.dart';

void main() {
  testWidgets('输入 GPA 回调 AcademicScore', (tester) async {
    AcademicScore? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GpaField(value: const AcademicScore(), onChanged: (s) => out = s),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('gpa-value')), '3.8');
    expect(out?.gpa, 3.8);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../../domain/entities/academic_score.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../../../shared/widgets/labeled_text_field.dart';

/// GPA 值 + 量纲单选 + 排名。任一变化回调新的 [AcademicScore]。
class GpaField extends StatelessWidget {
  const GpaField({super.key, required this.value, required this.onChanged});

  final AcademicScore value;
  final ValueChanged<AcademicScore> onChanged;

  static const List<(double, String)> _scales = [
    (4.0, '4.0'),
    (4.3, '4.3'),
    (4.5, '4.5'),
    (5.0, '5.0'),
    (100, '百分制'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledTextField(
          label: 'GPA / 平均分',
          fieldKey: const Key('gpa-value'),
          initialValue: value.gpa?.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hintText: '例 3.8',
          onChanged: (v) =>
              onChanged(_copy(gpa: double.tryParse(v.trim()), keepGpa: false)),
        ),
        const SizedBox(height: 12),
        const Text(
          '量纲',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ChoiceChipGroup<double>(
          options: _scales,
          selected: value.scale,
          onSelected: (s) => onChanged(_copy(scale: s)),
        ),
        const SizedBox(height: 12),
        LabeledTextField(
          label: '专业排名（可选）',
          initialValue: value.rank,
          hintText: '例 前 5% / 3/120',
          onChanged: (v) => onChanged(_copy(rank: v.trim())),
        ),
      ],
    );
  }

  // keepGpa=false 时允许把 gpa 清空为 null。
  AcademicScore _copy({double? gpa, bool keepGpa = true, double? scale, String? rank}) =>
      AcademicScore(
        gpa: keepGpa ? (gpa ?? value.gpa) : gpa,
        scale: scale ?? value.scale,
        rank: rank ?? value.rank,
      );
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(ui): GpaField molecule"`

---

### Task D6：AchievementItemCard（molecule）

**Files:** Create `lib/features/profile/widgets/achievement_item_card.dart`；Test `test/features/profile/widgets/achievement_item_card_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/profile/widgets/achievement_item_card.dart';

void main() {
  testWidgets('显示标题副标题；点删除回调', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AchievementItemCard(
            icon: Icons.emoji_events_outlined,
            title: 'ACM 区域赛',
            subtitle: '国家级 · 银牌 · 2024',
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.text('ACM 区域赛'), findsOneWidget);
    expect(find.text('国家级 · 银牌 · 2024'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(deleted, isTrue);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bento_tile.dart';

/// 单条成果展示卡：图标 + 标题/副标题 + 删除。可选 onTap 进编辑。
class AchievementItemCard extends StatelessWidget {
  const AchievementItemCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onDelete,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BentoTile(
      onTap: onTap,
      color: AppColors.surface,
      border: Border.all(color: AppColors.line),
      shadow: null,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: '删除',
            onPressed: () {
              Haptics.light();
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(ui): AchievementItemCard molecule"`

---

### Task D7：ProfileSectionTile（molecule）

**Files:** Create `lib/features/profile/widgets/profile_section_tile.dart`；Test `test/features/profile/widgets/profile_section_tile_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/profile/widgets/profile_section_tile.dart';

void main() {
  testWidgets('显示标题与摘要；点按回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSectionTile(
            title: '竞赛成果',
            summary: '2 项',
            done: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('竞赛成果'), findsOneWidget);
    expect(find.text('2 项'), findsOneWidget);
    await tester.tap(find.text('竞赛成果'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bento_tile.dart';

/// 档案中心分区卡：标题 + 摘要/状态 + 完成勾或箭头。
class ProfileSectionTile extends StatelessWidget {
  const ProfileSectionTile({
    super.key,
    required this.title,
    required this.summary,
    required this.done,
    required this.onTap,
  });

  final String title;
  final String summary;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BentoTile(
        onTap: onTap,
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        shadow: null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            Text(
              summary,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(width: 6),
            done
                ? const Icon(Icons.check_circle, size: 18, color: AppColors.match)
                : const Icon(Icons.chevron_right, size: 20, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(ui): ProfileSectionTile molecule"`

---

### Task D8：WizardScaffold（molecule）

**Files:** Create `lib/features/profile/widgets/wizard_scaffold.dart`；Test `test/features/profile/widgets/wizard_scaffold_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/profile/widgets/wizard_scaffold.dart';

void main() {
  testWidgets('显示标题与下一步；点下一步回调', (tester) async {
    var next = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WizardScaffold(
          title: '基本信息',
          index: 0,
          count: 3,
          nextLabel: '下一步',
          onNext: () => next = true,
          child: const Text('body'),
        ),
      ),
    );
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    expect(next, isTrue);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../shared/widgets/step_dots.dart';

/// 向导步骤外壳：进度点 + 标题 + 可滚动 body + 底部 sticky 上一步/下一步。
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.title,
    required this.index,
    required this.count,
    required this.child,
    required this.onNext,
    required this.nextLabel,
    this.onBack,
  });

  final String title;
  final int index;
  final int count;
  final Widget child;
  final VoidCallback onNext;
  final String nextLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('完善个人档案')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: StepDots(count: count, index: index),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(title, style: textTheme.headlineSmall),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: child,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (onBack != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Haptics.light();
                            onBack!();
                          },
                          child: const Text('上一步'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Haptics.light();
                          onNext();
                        },
                        child: Text(nextLabel),
                      ),
                    ),
                  ],
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

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(ui): WizardScaffold molecule"`

---

## Phase E · 组织件 / 状态 / 页面 / 接线

### Task E1：achievementsExtractionProvider（抽取调用状态）

**Files:** Create `lib/features/profile/providers/achievements_extraction_provider.dart`；Test `test/features/profile/achievements_extraction_provider_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition.dart';
import 'package:scho_navi/domain/repositories/profile_extraction_repository.dart';
import 'package:scho_navi/features/profile/providers/achievements_extraction_provider.dart';

class _FakeExtract implements ProfileExtractionRepository {
  @override
  Future<Result<AchievementDraft>> extract({required String rawText}) async =>
      const Success(
        AchievementDraft(competitions: [Competition(name: 'ACM 区域赛')]),
      );
}

void main() {
  test('extract 成功后 state 为含数据的 AsyncData', () async {
    final container = ProviderContainer(
      overrides: [
        profileExtractionRepositoryProvider.overrideWithValue(_FakeExtract()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(achievementsExtractionProvider.notifier)
        .extract('自述文本');

    final state = container.read(achievementsExtractionProvider);
    expect(state.value?.competitions.single.name, 'ACM 区域赛');
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/repositories/profile_extraction_repository.dart';

/// 「AI 整理」调用状态。null=未抽取；loading/data/error 由 UI 渲染。
class AchievementsExtractionController
    extends Notifier<AsyncValue<AchievementDraft?>> {
  @override
  AsyncValue<AchievementDraft?> build() => const AsyncData(null);

  Future<void> extract(String rawText) async {
    state = const AsyncLoading();
    final result =
        await ref.read(profileExtractionRepositoryProvider).extract(rawText: rawText);
    state = switch (result) {
      Success(:final data) => AsyncData(data),
      Failure(:final error) => AsyncError(error, StackTrace.current),
    };
  }

  void reset() => state = const AsyncData(null);
}

final achievementsExtractionProvider = NotifierProvider<
    AchievementsExtractionController, AsyncValue<AchievementDraft?>>(
  AchievementsExtractionController.new,
);
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(profile): achievementsExtractionProvider (AI extract call state)"`

---

### Task E2：BasicInfoForm（organism）

**Files:** Create `lib/features/profile/widgets/basic_info_form.dart`；Test `test/features/profile/widgets/basic_info_form_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/features/profile/widgets/basic_info_form.dart';

void main() {
  testWidgets('选性别回调更新 profile', (tester) async {
    UserProfile? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BasicInfoForm(
              value: const UserProfile(),
              onChanged: (p) => out = p,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('女'));
    expect(out?.gender, Gender.female);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../../domain/entities/user_profile.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../../../shared/widgets/labeled_text_field.dart';

/// 基本信息表单 organism（向导①与中心编辑复用）。
class BasicInfoForm extends StatelessWidget {
  const BasicInfoForm({super.key, required this.value, required this.onChanged});

  final UserProfile value;
  final ValueChanged<UserProfile> onChanged;

  static const List<(Gender, String)> _genders = [
    (Gender.male, '男'),
    (Gender.female, '女'),
    (Gender.other, '其他'),
    (Gender.undisclosed, '不愿透露'),
  ];

  static const List<(String, String)> _stages = [
    ('本科在读', '本科在读'),
    ('硕士在读', '硕士在读'),
    ('已毕业', '已毕业'),
  ];

  static const List<(String, String)> _targets = [
    ('申请硕士', '申请硕士'),
    ('申请博士', '申请博士'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledTextField(
          label: '姓名 / 称呼',
          initialValue: value.name,
          onChanged: (v) => onChanged(value.copyWith(name: v.trim())),
        ),
        const SizedBox(height: 14),
        const _Label('性别'),
        ChoiceChipGroup<Gender>(
          options: _genders,
          selected: value.gender,
          onSelected: (g) => onChanged(value.copyWith(gender: g)),
        ),
        const SizedBox(height: 14),
        LabeledTextField(
          label: '现就读学校',
          initialValue: value.school,
          onChanged: (v) => onChanged(value.copyWith(school: v.trim())),
        ),
        const SizedBox(height: 14),
        LabeledTextField(
          label: '专业',
          initialValue: value.major,
          onChanged: (v) => onChanged(value.copyWith(major: v.trim())),
        ),
        const SizedBox(height: 14),
        const _Label('当前阶段'),
        ChoiceChipGroup<String>(
          options: _stages,
          selected: value.degreeStage,
          onSelected: (s) => onChanged(value.copyWith(degreeStage: s)),
        ),
        const SizedBox(height: 14),
        const _Label('目标阶段'),
        ChoiceChipGroup<String>(
          options: _targets,
          selected: value.targetDegree,
          onSelected: (t) => onChanged(value.copyWith(targetDegree: t)),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(profile): BasicInfoForm organism"`

---

### Task E3：ScoreAndInterestsForm（organism）

**Files:** Create `lib/features/profile/widgets/score_and_interests_form.dart`；Test `test/features/profile/widgets/score_and_interests_form_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/features/profile/widgets/score_and_interests_form.dart';

void main() {
  testWidgets('添加研究兴趣回调更新', (tester) async {
    UserProfile? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScoreAndInterestsForm(
              value: const UserProfile(),
              onChanged: (p) => out = p,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('interest-input')), '人工智能');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(out?.researchInterests, contains('人工智能'));
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/academic_score.dart';
import '../../../domain/entities/user_profile.dart';
import 'gpa_field.dart';

/// 成绩 + 研究兴趣表单 organism。
class ScoreAndInterestsForm extends StatefulWidget {
  const ScoreAndInterestsForm({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UserProfile value;
  final ValueChanged<UserProfile> onChanged;

  @override
  State<ScoreAndInterestsForm> createState() => _ScoreAndInterestsFormState();
}

class _ScoreAndInterestsFormState extends State<ScoreAndInterestsForm> {
  final TextEditingController _interest = TextEditingController();

  @override
  void dispose() {
    _interest.dispose();
    super.dispose();
  }

  void _addInterest() {
    final v = _interest.text.trim();
    if (v.isEmpty || widget.value.researchInterests.contains(v)) return;
    Haptics.selection();
    widget.onChanged(
      widget.value.copyWith(
        researchInterests: [...widget.value.researchInterests, v],
      ),
    );
    _interest.clear();
  }

  void _removeInterest(String v) {
    widget.onChanged(
      widget.value.copyWith(
        researchInterests:
            widget.value.researchInterests.where((e) => e != v).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.value.score ?? const AcademicScore();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GpaField(
          value: score,
          onChanged: (s) => widget.onChanged(widget.value.copyWith(score: s)),
        ),
        const SizedBox(height: 18),
        const Text(
          '研究兴趣',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('interest-input'),
          controller: _interest,
          decoration: InputDecoration(
            hintText: '输入后回车添加，如 计算机视觉',
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addInterest,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onSubmitted: (_) => _addInterest(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in widget.value.researchInterests)
              Chip(
                label: Text(tag),
                onDeleted: () => _removeInterest(tag),
                backgroundColor: AppColors.panel,
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(profile): ScoreAndInterestsForm organism"`

---

### Task E4：AchievementsEditor（organism · AI 抽取核心）

**Files:** Create `lib/features/profile/widgets/achievements_editor.dart`；Test `test/features/profile/widgets/achievements_editor_test.dart`

- [ ] **Step 1：写失败测试（手动删除 + AI 整理合并）**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_extraction_repository.dart';
import 'package:scho_navi/features/profile/widgets/achievements_editor.dart';

class _FakeExtract implements ProfileExtractionRepository {
  @override
  Future<Result<AchievementDraft>> extract({required String rawText}) async =>
      const Success(
        AchievementDraft(competitions: [Competition(name: '挑战杯', award: '一等奖')]),
      );
}

void main() {
  testWidgets('AI 整理把抽取结果合并进 profile', (tester) async {
    UserProfile current = const UserProfile();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileExtractionRepositoryProvider.overrideWithValue(_FakeExtract()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: AchievementsEditor(
                  value: current,
                  onChanged: (p) => setState(() => current = p),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('achievements-raw')),
      '挑战杯一等奖',
    );
    await tester.tap(find.text('AI 整理成条目'));
    await tester.pump(); // loading
    await tester.pumpAndSettle(); // done
    expect(current.competitions.any((c) => c.name == '挑战杯'), isTrue);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/competition.dart';
import '../../../domain/entities/research_item.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../providers/achievements_extraction_provider.dart';
import 'achievement_item_card.dart';

/// 成果编辑 organism：自由文本 +「AI 整理」(可选加速) + 条目列表(手动删/加)。
class AchievementsEditor extends ConsumerStatefulWidget {
  const AchievementsEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UserProfile value;
  final ValueChanged<UserProfile> onChanged;

  @override
  ConsumerState<AchievementsEditor> createState() => _AchievementsEditorState();
}

class _AchievementsEditorState extends ConsumerState<AchievementsEditor> {
  final TextEditingController _raw = TextEditingController();

  @override
  void dispose() {
    _raw.dispose();
    super.dispose();
  }

  void _mergeDraft(AchievementDraft draft) {
    Haptics.success();
    widget.onChanged(
      widget.value.copyWith(
        competitions: [...widget.value.competitions, ...draft.competitions],
        research: [...widget.value.research, ...draft.research],
      ),
    );
    ref.read(achievementsExtractionProvider.notifier).reset();
    _raw.clear();
  }

  void _removeCompetition(int i) {
    final next = [...widget.value.competitions]..removeAt(i);
    widget.onChanged(widget.value.copyWith(competitions: next));
  }

  void _removeResearch(int i) {
    final next = [...widget.value.research]..removeAt(i);
    widget.onChanged(widget.value.copyWith(research: next));
  }

  @override
  Widget build(BuildContext context) {
    final aiOn = ref.watch(appConfigProvider).dataSource == DataSource.ai;
    final extraction = ref.watch(achievementsExtractionProvider);

    // 抽取成功后合并（在 build 外通过 listen 触发更稳妥）。
    ref.listen(achievementsExtractionProvider, (prev, next) {
      final draft = next.value;
      if (draft != null) _mergeDraft(draft);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('achievements-raw'),
          controller: _raw,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '粘贴/输入你的竞赛、论文、项目、专利等经历，如：'
                'ACM 区域赛银牌；一篇 EI 一作论文…',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        if (extraction.isLoading)
          const ShimmerSkeleton(height: 44, child: SizedBox.expand())
        else
          FilledButton.icon(
            onPressed: aiOn
                ? () {
                    final text = _raw.text.trim();
                    if (text.isEmpty) return;
                    Haptics.medium();
                    ref
                        .read(achievementsExtractionProvider.notifier)
                        .extract(text);
                  }
                : null,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(aiOn ? 'AI 整理成条目' : 'AI 整理（需开启 AI 模式）'),
          ),
        if (extraction.hasError)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('整理失败，请重试或手动添加', style: TextStyle(color: AppColors.danger)),
          ),
        const SizedBox(height: 16),
        _Header(
          label: '竞赛成果',
          onAdd: () => _showCompetitionDialog(),
        ),
        for (var i = 0; i < widget.value.competitions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AchievementItemCard(
              icon: Icons.emoji_events_outlined,
              title: widget.value.competitions[i].name,
              subtitle: _competitionSubtitle(widget.value.competitions[i]),
              onDelete: () => _removeCompetition(i),
            ),
          ),
        const SizedBox(height: 12),
        _Header(label: '科研成果', onAdd: () => _showResearchDialog()),
        for (var i = 0; i < widget.value.research.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AchievementItemCard(
              icon: Icons.article_outlined,
              title: widget.value.research[i].title,
              subtitle: _researchSubtitle(widget.value.research[i]),
              onDelete: () => _removeResearch(i),
            ),
          ),
      ],
    );
  }

  String _competitionSubtitle(Competition c) =>
      [c.level, c.award, c.year].where((e) => e != null && e.isNotEmpty).join(' · ');

  String _researchSubtitle(ResearchItem r) =>
      [r.role, r.venueOrStatus, r.year].where((e) => e != null && e!.isNotEmpty).join(' · ');

  Future<void> _showCompetitionDialog() async {
    final name = TextEditingController();
    final award = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加竞赛'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: '名称')),
            TextField(controller: award, decoration: const InputDecoration(labelText: '奖项（可选）')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('添加')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      widget.onChanged(
        widget.value.copyWith(
          competitions: [
            ...widget.value.competitions,
            Competition(
              name: name.text.trim(),
              award: award.text.trim().isEmpty ? null : award.text.trim(),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showResearchDialog() async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加科研成果'),
        content: TextField(
          controller: title,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('添加')),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      widget.onChanged(
        widget.value.copyWith(
          research: [
            ...widget.value.research,
            ResearchItem(type: ResearchType.other, title: title.text.trim()),
          ],
        ),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.label, required this.onAdd});
  final String label;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      const Spacer(),
      TextButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('手动添加'),
      ),
    ],
  );
}
```

- [ ] **Step 4：跑测试确认通过** — Run: `flutter test test/features/profile/widgets/achievements_editor_test.dart` → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(profile): AchievementsEditor organism (manual + AI extract)"`

---

### Task E5：ProfileSummaryHeader（organism）

**Files:** Create `lib/features/profile/widgets/profile_summary_header.dart`；Test `test/features/profile/widgets/profile_summary_header_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/features/profile/widgets/profile_summary_header.dart';

void main() {
  testWidgets('显示完成度环与 CTA', (tester) async {
    var used = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSummaryHeader(
            profile: const UserProfile(name: '张三', gender: Gender.male),
            onUseForReco: () => used = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('用我的档案推荐'), findsOneWidget);
    await tester.tap(find.text('用我的档案推荐'));
    expect(used, isTrue);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../shared/widgets/completion_ring.dart';

/// 档案中心顶部：完成度环 + 标语 + CTA。
class ProfileSummaryHeader extends StatelessWidget {
  const ProfileSummaryHeader({
    super.key,
    required this.profile,
    required this.onUseForReco,
  });

  final UserProfile profile;
  final VoidCallback onUseForReco;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CompletionRing(value: profile.completion),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '档案完成度',
                      style: TextStyle(color: AppColors.paper, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '越完整 · 推荐越准',
                      style: const TextStyle(
                        color: AppColors.lime,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onUseForReco,
              child: const Text('用我的档案推荐'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(profile): ProfileSummaryHeader organism"`

---

### Task E6：ProfilePromptSheet（即时触发）

**Files:** Create `lib/features/profile/widgets/profile_prompt_sheet.dart`；Test `test/features/profile/widgets/profile_prompt_sheet_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/profile/widgets/profile_prompt_sheet.dart';

void main() {
  testWidgets('点「去完善」返回 true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async =>
                  result = await showProfilePromptSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('去完善'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';

/// 即时触发底部 sheet。返回 true=去完善，false/null=跳过。
Future<bool?> showProfilePromptSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '完善档案，推荐更准',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            '花 1 分钟填写你的成绩、竞赛、科研背景，让推荐结合你的真实情况。资料仅保存在本机。',
            style: TextStyle(color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Haptics.medium();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('去完善'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Haptics.light();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('先跳过'),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(profile): ProfilePromptSheet (just-in-time trigger)"`

---

### Task E7：ProfileWizardPage（页面，渐进保存）

**Files:** Create `lib/features/profile/pages/profile_wizard_page.dart`；Test `test/features/profile/profile_wizard_page_test.dart`

- [ ] **Step 1：写失败测试（走完 3 步落盘并跳 /profile）**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/profile/pages/profile_wizard_page.dart';
import 'package:scho_navi/features/profile/providers/profile_provider.dart';

class _MemProfileRepo implements ProfileRepository {
  UserProfile p = const UserProfile();
  @override
  UserProfile load() => p;
  @override
  Future<void> save(UserProfile profile) async => p = profile;
}

void main() {
  testWidgets('填姓名→走到末步→完成，落盘并跳 /profile', (tester) async {
    final repo = _MemProfileRepo();
    final router = GoRouter(
      initialLocation: '/profile/wizard',
      routes: [
        GoRoute(path: '/profile/wizard', builder: (_, _) => const ProfileWizardPage()),
        GoRoute(path: '/profile', builder: (_, _) => const Text('hub-marker')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '张三');
    // 步 1 → 2 → 3
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('hub-marker'), findsOneWidget);
    expect(repo.load().name, '张三');
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/user_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/achievements_editor.dart';
import '../widgets/basic_info_form.dart';
import '../widgets/score_and_interests_form.dart';
import '../widgets/wizard_scaffold.dart';

/// 首填向导：3 步，每步「下一步」渐进落盘，末步「完成」→ /profile。
class ProfileWizardPage extends ConsumerStatefulWidget {
  const ProfileWizardPage({super.key});

  @override
  ConsumerState<ProfileWizardPage> createState() => _ProfileWizardPageState();
}

class _ProfileWizardPageState extends ConsumerState<ProfileWizardPage> {
  int _step = 0;
  late UserProfile _draft = ref.read(profileProvider);

  Future<void> _persist() => ref.read(profileProvider.notifier).save(_draft);

  Future<void> _next() async {
    await _persist();
    if (_step < 2) {
      setState(() => _step++);
    } else if (mounted) {
      context.go('/profile');
    }
  }

  void _back() => setState(() => _step--);

  @override
  Widget build(BuildContext context) {
    final (title, child) = switch (_step) {
      0 => (
        '基本信息',
        BasicInfoForm(
          value: _draft,
          onChanged: (p) => setState(() => _draft = p),
        ),
      ),
      1 => (
        '成绩 & 方向',
        ScoreAndInterestsForm(
          value: _draft,
          onChanged: (p) => setState(() => _draft = p),
        ),
      ),
      _ => (
        '成果',
        AchievementsEditor(
          value: _draft,
          onChanged: (p) => setState(() => _draft = p),
        ),
      ),
    };

    return WizardScaffold(
      title: title,
      index: _step,
      count: 3,
      onBack: _step == 0 ? null : _back,
      onNext: _next,
      nextLabel: _step == 2 ? '完成' : '下一步',
      child: child,
    );
  }
}
```

- [ ] **Step 4：跑测试确认通过** → PASS。
- [ ] **Step 5：Commit** — `git commit -m "feat(profile): ProfileWizardPage (3-step, progressive save)"`

---

### Task E8：ProfilePage（档案中心）

**Files:** Create `lib/features/profile/pages/profile_page.dart`；Test `test/features/profile/profile_page_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/profile/pages/profile_page.dart';

class _Repo implements ProfileRepository {
  _Repo(this._p);
  UserProfile _p;
  @override
  UserProfile load() => _p;
  @override
  Future<void> save(UserProfile profile) async => _p = profile;
}

void main() {
  testWidgets('展示分区卡与完成度', (tester) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfilePage())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            _Repo(const UserProfile(name: '张三', gender: Gender.male)),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('竞赛成果'), findsOneWidget);
  });
}
```

- [ ] **Step 2：跑测试确认失败** → 编译错误。

- [ ] **Step 3：实现**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_bottom_sheet.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../providers/profile_provider.dart';
import '../widgets/achievements_editor.dart';
import '../widgets/basic_info_form.dart';
import '../widgets/profile_section_tile.dart';
import '../widgets/profile_summary_header.dart';
import '../widgets/score_and_interests_form.dart';

/// 档案中心：完成度头 + 分区卡（点开聚焦编辑，复用向导 organism）。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的档案')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedEntrance(
            index: 0,
            child: ProfileSummaryHeader(
              profile: profile,
              onUseForReco: () => context.go('/home'),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedEntrance(
            index: 1,
            child: ProfileSectionTile(
              title: '基本信息',
              summary: profile.name ?? '待填写',
              done: profile.name != null && profile.gender != null,
              onTap: () => _editBasic(context, ref, profile),
            ),
          ),
          AnimatedEntrance(
            index: 2,
            child: ProfileSectionTile(
              title: '成绩 & 方向',
              summary: profile.score?.gpa != null ? 'GPA ${profile.score!.gpa}' : '待填写',
              done: profile.score?.gpa != null,
              onTap: () => _editScore(context, ref, profile),
            ),
          ),
          AnimatedEntrance(
            index: 3,
            child: ProfileSectionTile(
              title: '竞赛成果',
              summary: '${profile.competitions.length} 项',
              done: profile.competitions.isNotEmpty,
              onTap: () => _editAchievements(context, ref, profile),
            ),
          ),
          AnimatedEntrance(
            index: 4,
            child: ProfileSectionTile(
              title: '科研成果',
              summary: '${profile.research.length} 项',
              done: profile.research.isNotEmpty,
              onTap: () => _editAchievements(context, ref, profile),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBasic(BuildContext context, WidgetRef ref, UserProfile p) =>
      _editSheet(context, ref, p, (draft, onChanged) => BasicInfoForm(value: draft, onChanged: onChanged));

  Future<void> _editScore(BuildContext context, WidgetRef ref, UserProfile p) =>
      _editSheet(context, ref, p, (draft, onChanged) => ScoreAndInterestsForm(value: draft, onChanged: onChanged));

  Future<void> _editAchievements(BuildContext context, WidgetRef ref, UserProfile p) =>
      _editSheet(context, ref, p, (draft, onChanged) => AchievementsEditor(value: draft, onChanged: onChanged));

  Future<void> _editSheet(
    BuildContext context,
    WidgetRef ref,
    UserProfile initial,
    Widget Function(UserProfile draft, ValueChanged<UserProfile> onChanged) builder,
  ) async {
    var draft = initial;
    await showAppBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                builder(draft, (p) => setState(() => draft = p)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('保存'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
    await ref.read(profileProvider.notifier).save(draft);
  }
}
```

> **注意**：`showAppBottomSheet<T>({required BuildContext context, required WidgetBuilder builder, bool expand = false})`（`lib/core/ui/app_bottom_sheet.dart`）已内置 `isScrollControlled`/`showDragHandle`/`useSafeArea` 与键盘避让（底部 viewInsets padding），故 sheet 内部无需再加 bottom padding。

- [ ] **Step 2.5：analyze**

Run: `flutter analyze lib/features/profile/pages/profile_page.dart`
Expected: No issues found.

- [ ] **Step 3：跑测试确认通过** → Run: `flutter test test/features/profile/profile_page_test.dart` → PASS。
- [ ] **Step 4：Commit** — `git commit -m "feat(profile): ProfilePage hub (sections reuse wizard organisms)"`

---

### Task E9：路由接线 /profile 与 /profile/wizard

**Files:** Modify `lib/core/router/app_router.dart`；Test `test/core/router/`（若有路由测试则追加，否则跳过）

- [ ] **Step 1：加路由**

在 `app_router.dart` import 区加：

```dart
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/profile_wizard_page.dart';
```

在 `routes` 列表中 `GoRoute(path: '/settings', ...)` 之后加：

```dart
      GoRoute(
        path: '/profile',
        pageBuilder: (_, state) =>
            sharedAxisPage(state: state, child: const ProfilePage()),
      ),
      GoRoute(
        path: '/profile/wizard',
        pageBuilder: (_, state) =>
            sharedAxisPage(state: state, child: const ProfileWizardPage()),
      ),
```

- [ ] **Step 2：analyze** — Run: `flutter analyze lib/core/router/app_router.dart` → No issues。
- [ ] **Step 3：Commit** — `git commit -m "feat(router): add /profile and /profile/wizard routes"`

---

### Task E10：首页入口 + 即时触发

**Files:** Modify `lib/features/home/pages/home_page.dart`；Test `test/features/home/`（追加触发用例）

- [ ] **Step 1：把 HomePage 改为 Consumer 并加入口/触发**

a) 顶部 import 加：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/widgets/profile_prompt_sheet.dart';
import '../../profile/providers/profile_provider.dart';
```

b) 类声明改为 Consumer：

```dart
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const String promptDismissedKey = 'profile_prompt_dismissed';
```

（其余 state 字段不变；`State<HomePage>` 改为 `ConsumerState<HomePage>`，原 `extends State<HomePage>` 那行删除——已并入上面。）

c) AppBar `actions` 在 设置 IconButton 之前加档案入口：

```dart
          IconButton(
            tooltip: '我的档案',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
```

d) 把 `_submit()` 改为异步、先触发档案引导：

```dart
  Future<void> _submit() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;
    if (prompt.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('可补充研究方向或地区，描述更具体会更准哦')),
      );
    }

    final store = ref.read(localStoreProvider);
    final dismissed = store.getBool(promptDismissedKey) ?? false;
    if (ref.read(profileProvider).isEmpty && !dismissed) {
      final go = await showProfilePromptSheet(context);
      if (!mounted) return;
      if (go == true) {
        context.push('/profile/wizard');
        return; // 去完善，稍后再来推荐
      }
      await store.setBool(promptDismissedKey, true);
      if (!mounted) return;
    }

    context.push('/recommendation?q=${Uri.encodeComponent(prompt)}');
  }
```

并补 import：`import '../../../core/di/providers.dart';`（若未引入 `localStoreProvider`）。`_submit` 的调用方 `FilledButton(onPressed: ... _submit())` 改为 `() { Haptics.medium(); _submit(); }`（已是该形态，保持）。

- [ ] **Step 2：写触发测试 `test/features/home/home_prompt_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/home/pages/home_page.dart';

Future<ProviderContainer> _c() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('空档案首次提交弹出完善档案 sheet', (tester) async {
    final c = await _c();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(path: '/profile/wizard', builder: (_, _) => const Text('wizard')),
        GoRoute(path: '/recommendation', builder: (_, _) => const Text('reco')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '我想找计算机视觉方向导师');
    await tester.tap(find.text('开始推荐'));
    await tester.pumpAndSettle();

    expect(find.text('完善档案，推荐更准'), findsOneWidget);
  });
}
```

- [ ] **Step 3：跑测试确认通过** — Run: `flutter test test/features/home/home_prompt_test.dart` → PASS。并跑既有首页测试确认未破：`flutter test test/features/home`。
- [ ] **Step 4：Commit** — `git commit -m "feat(home): profile entry + just-in-time profile prompt"`

---

### Task E11：设置页入口 + 隐私行

**Files:** Modify `lib/features/settings/pages/settings_page.dart`

- [ ] **Step 1：加档案入口与隐私说明**

a) 在 `body: ListView(... children: [` 顶部（第一个 SectionHeader 之前）加入档案入口分区：

```dart
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('个人'),
          ),
          ListTile(
            key: const Key('settings-profile-entry'),
            leading: const Icon(Icons.person_outline),
            title: const Text('我的背景档案'),
            subtitle: const Text('用于让推荐结合你的成绩 / 竞赛 / 科研'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Haptics.light();
              context.push('/profile');
            },
          ),
          const Divider(),
```

b) 在「隐私」SectionHeader 之后、「清除本地数据」ListTile 之前，加一行说明：

```dart
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('数据如何使用'),
            subtitle: Text('资料仅保存在本机；AI 模式下会随请求发送给大模型用于解析与推荐。'),
          ),
```

c) 顶部 import 加：`import 'package:go_router/go_router.dart';`（用 `context.push`）。

- [ ] **Step 2：analyze + 跑既有设置测试** — Run: `flutter analyze lib/features/settings/pages/settings_page.dart && flutter test test/features/settings` → 全绿（既有测试不应受影响）。
- [ ] **Step 3：Commit** — `git commit -m "feat(settings): profile entry + data-usage privacy line"`

---

### Task E12：套磁/匹配并入统一档案

**Files:** Modify `lib/features/email/pages/email_page.dart`、`lib/features/email/widgets/profile_sheet.dart`、`lib/features/match/pages/match_page.dart`

- [ ] **Step 1：确认现状**

Run: `flutter analyze lib/features/email/pages/email_page.dart lib/features/match/pages/match_page.dart`
打开三个文件，定位它们如何获取 `UserProfile`（当前应是经 `showProfileSheet` 或 `profileRepositoryProvider.load()`）。

- [ ] **Step 2：改为读 `profileProvider`**

在 `email_page.dart` / `match_page.dart` 中，把"读取档案"的来源换成 `ref.watch(profileProvider)`（import `../../profile/providers/profile_provider.dart`）。把原先点击「完善背景」打开 `showProfileSheet` 的入口，改为 `context.push('/profile')`（import go_router）。删除对 `showProfileSheet` 的调用。

- [ ] **Step 3：移除旧 `profile_sheet.dart`**

确认 `showProfileSheet` / `ProfileSheet` 已无引用：
Run: `grep -rn "showProfileSheet\|ProfileSheet" lib test`
若无残留，删除 `lib/features/email/widgets/profile_sheet.dart` 及其测试（若有 `test/features/email/profile_sheet_test.dart` 则一并删除或改写为指向 `/profile`）。

- [ ] **Step 4：回归** — Run: `flutter test test/features/email test/features/match && flutter analyze` → 全绿。
- [ ] **Step 5：Commit** — `git commit -m "refactor(profile): unify email/match profile via profileProvider; remove legacy profile_sheet"`

---

## Phase F · 隐私文案 / 打磨 / 回归

### Task F1：向导首屏隐私说明

**Files:** Modify `lib/features/profile/pages/profile_wizard_page.dart`

- [ ] **Step 1：在向导第①步顶部加隐私提示条**

把 `_step == 0` 的 `child` 改为在 `BasicInfoForm` 上方包一条说明：

```dart
      0 => (
        '基本信息',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F4EC), // AppColors.matchSoft
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '资料仅保存在本机；AI 模式下会随请求发送给大模型用于解析与推荐。',
                style: TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ),
            BasicInfoForm(
              value: _draft,
              onChanged: (p) => setState(() => _draft = p),
            ),
          ],
        ),
      ),
```

（顶部已 import `package:flutter/material.dart`；如愿用 `AppColors.matchSoft` 可 import `../../../core/theme/app_colors.dart` 替换字面色值。）

- [ ] **Step 2：跑向导测试确认未破** — Run: `flutter test test/features/profile/profile_wizard_page_test.dart` → PASS。
- [ ] **Step 3：Commit** — `git commit -m "feat(profile): privacy notice on wizard first step"`

---

### Task F2：全量回归 + 静态检查 + 冒烟

- [ ] **Step 1：全量测试** — Run: `flutter test`
Expected: All tests passed（含引擎计划 + 本计划新增 + 既有回归）。
若 `home`/`router`/`e2e` 等既有 widget 测试因首页改 Consumer 或新路由失败，按报错补 `sharedPreferencesProvider` override / 路由占位，使其恢复绿。

- [ ] **Step 2：静态检查** — Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3：真机/模拟器冒烟（AI 模式）**

Run: `flutter run --dart-define=LLM_API_KEY=<你的key>`
手测：首页输入查询 → 弹「完善档案」→ 去完善 → 向导三步（含「AI 整理」抽取竞赛/科研）→ 完成落到档案中心（完成度环动画）→ 中心「用我的档案推荐」→ 推荐理由是否引用背景 → 设置页「我的背景档案」入口 + 数据使用说明。

- [ ] **Step 4：Commit（如有打磨修补）** — `git commit -m "chore(profile): regression fixes and polish"`

---

## 自检清单（执行者完成全部 Task 后）

- [ ] `flutter test` 全绿、`flutter analyze` 无 issue。
- [ ] spec Phase D/E/F 覆盖：原子/分子/组织件✓、向导(B)✓、中心(C)✓、即时触发✓、入口(首页/设置)✓、email/match 并入✓、隐私文案✓。
- [ ] 端到端：空档案触发 → 向导 → 中心 → 推荐感知背景，全链路通。
- [ ] 原子化验收：`BasicInfoForm` 等 organism 在「向导」与「中心编辑」两处复用同一实现。

> 至此「个人档案 → 个性化推荐」用户故事端到端交付完成。后续（独立）：清退既有假分析仓储、真实后端 HTTP 实现（见 spec §15/§10）。
