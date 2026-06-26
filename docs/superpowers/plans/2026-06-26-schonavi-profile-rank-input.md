# 专业排名结构化输入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把个人档案的「专业排名」从自由文本输入改为二选一（百分制 / 名次+总人数 / 不填）的结构化数字输入，通过受限输入与即时校验保证存入数据必然合法。

**Architecture:** `AcademicScore` 实体新增 `RankMode` 枚举与 `percent`/`rankPosition`/`rankTotal` 三个整数字段，`rank` 由计算 getter 生成（`"前 5%"` / `"3/120"` / `null`），下游两个 AI 推荐仓库读 `rank` 的代码零改动。新增 `RankField` widget 负责模式切换 + 受限数字输入 + 即时校验（不合法不回调 + 标红），`GpaField` 移除原排名文本框、接入 `RankField`。`LabeledTextField` 加 `errorText` 参数支持错误展示。`LocalProfileRepository` 直接用 `AcademicScore.fromJson/toJson`，无需改动。

**Tech Stack:** Flutter / Dart，Riverpod 3.2.1，flutter_test widget 测试，shared_preferences 本地持久化。

## Global Constraints

- 测试约定：先写失败测试 → 跑红 → 实现 → 跑绿 → commit。每个 task 独立测试周期。
- Widget 测试脚手架统一用 `MaterialApp(home: Scaffold(body: ...))`；本特性不涉及 Riverpod（`GpaField`/`RankField` 都是受控 widget，`value` + `onChanged`）。
- `AcademicScore` 构造函数所有排名字段有默认值（`rankMode: RankMode.none`，其余 null），现有 `const AcademicScore()` 调用不破坏。
- `rank` 是计算 getter，不再作为构造参数、不再出现在 `toJson`/`fromJson`。旧版 JSON 里的 `rank` 字符串在 `fromJson` 中忽略（开发阶段清空）。
- 校验强制方式：不合法时 `RankField` 不调用 `onChanged`（外部 state 保持上一个合法值）+ `LabeledTextField` 的 `errorText` 标红。
- 量纲 `scale` 取 4.0/4.3/4.5/5.0/100，与排名无关；本计划不动 GPA/量纲逻辑，只改其 `onChanged` 用 `withGpa`/`withScale` 保留排名字段。
- 全程 `flutter test` 与 `flutter analyze` 保持绿。

---

## File Structure

| 文件 | 职责 | 动作 |
|---|---|---|
| `lib/domain/entities/academic_score.dart` | `AcademicScore` 实体 + `RankMode` 枚举 + `rank` getter + `with*` helper + 序列化 | 修改 |
| `lib/data/dto/profile_dtos.dart` | `AcademicScoreDto` 同步结构化字段 | 修改 |
| `lib/shared/widgets/labeled_text_field.dart` | 通用带标签输入框，加 `errorText` 参数 | 修改 |
| `lib/features/profile/widgets/rank_field.dart` | 排名输入 widget：模式切换 + 受限输入 + 校验 | 新建 |
| `lib/features/profile/widgets/gpa_field.dart` | GPA/量纲/排名组合，移除排名文本框、接入 `RankField` | 修改 |
| `test/domain/entities/academic_score_test.dart` | 实体 getter/helper/序列化测试 | 新建 |
| `test/data/dto/profile_dtos_test.dart` | DTO 排名字段往返测试 | 新建 |
| `test/features/profile/widgets/rank_field_test.dart` | `RankField` 交互与校验测试 | 新建 |
| `test/features/profile/widgets/gpa_field_test.dart` | GPA 集成：排名字段保留测试 | 修改 |
| `test/data/local/local_profile_repository_test.dart` | 持久化往返改为结构化构造 | 修改 |

零改动（验证不变）：`lib/data/ai/ai_recommendation_repository.dart:86`、`lib/data/ai/ai_competition_recommendation_repository.dart:94`（读 `p.score!.rank`）、`lib/data/local/local_profile_repository.dart`（委托 `AcademicScore.fromJson/toJson`）、`lib/features/profile/providers/profile_provider.dart`。

---

### Task 1: 扩展 `AcademicScore` 实体

**Files:**
- Modify: `lib/domain/entities/academic_score.dart`（整文件重写）
- Test: `test/domain/entities/academic_score_test.dart`（新建）

**Interfaces:**
- Produces: `enum RankMode { none, percent, ordinal }`；`AcademicScore({double? gpa, double? scale, RankMode rankMode = RankMode.none, int? percent, int? rankPosition, int? rankTotal})`；`String? get rank`；`AcademicScore withGpa(double?)` / `withScale(double?)` / `withRank({required RankMode mode, int? percent, int? rankPosition, int? rankTotal})`；`toJson()`/`fromJson()` 持久化结构化字段。

- [ ] **Step 1: 写失败测试**

创建 `test/domain/entities/academic_score_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';

void main() {
  group('rank getter', () {
    test('none -> null', () {
      expect(const AcademicScore().rank, isNull);
    });
    test('percent=5 -> 前 5%', () {
      const score = AcademicScore(rankMode: RankMode.percent, percent: 5);
      expect(score.rank, '前 5%');
    });
    test('ordinal 3/120 -> 3/120', () {
      const score = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      expect(score.rank, '3/120');
    });
    test('percent mode 但 percent=null -> null', () {
      const score = AcademicScore(rankMode: RankMode.percent);
      expect(score.rank, isNull);
    });
    test('ordinal 缺 position -> null', () {
      const score = AcademicScore(rankMode: RankMode.ordinal, rankTotal: 120);
      expect(score.rank, isNull);
    });
    test('ordinal 缺 total -> null', () {
      const score = AcademicScore(rankMode: RankMode.ordinal, rankPosition: 3);
      expect(score.rank, isNull);
    });
  });

  group('isEmpty', () {
    test('全空 -> true', () {
      expect(const AcademicScore().isEmpty, isTrue);
    });
    test('只设 gpa -> false', () {
      const score = AcademicScore(gpa: 3.8);
      expect(score.isEmpty, isFalse);
    });
    test('mode=none -> true（rank 为 null）', () {
      const score = AcademicScore(rankMode: RankMode.none);
      expect(score.isEmpty, isTrue);
    });
    test('percent=5 -> false', () {
      const score = AcademicScore(rankMode: RankMode.percent, percent: 5);
      expect(score.isEmpty, isFalse);
    });
  });

  group('withGpa / withScale / withRank', () {
    test('withGpa 保留排名字段', () {
      const base = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      final out = base.withGpa(3.9);
      expect(out.gpa, 3.9);
      expect(out.rankMode, RankMode.ordinal);
      expect(out.rankPosition, 3);
      expect(out.rankTotal, 120);
    });
    test('withScale 保留排名字段', () {
      const base = AcademicScore(
        rankMode: RankMode.percent, percent: 5,
      );
      final out = base.withScale(4.0);
      expect(out.scale, 4.0);
      expect(out.rankMode, RankMode.percent);
      expect(out.percent, 5);
    });
    test('withRank(mode: none) 清空三件套', () {
      const base = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      final out = base.withRank(mode: RankMode.none);
      expect(out.rankMode, RankMode.none);
      expect(out.percent, isNull);
      expect(out.rankPosition, isNull);
      expect(out.rankTotal, isNull);
      expect(out.rank, isNull);
    });
    test('withRank(mode: percent) 未传字段保留原值（回带语义）', () {
      // 从名次切到百分制：切回时名次旧值仍由 value 带回
      const base = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      final out = base.withRank(mode: RankMode.percent);
      expect(out.rankMode, RankMode.percent);
      expect(out.rankPosition, 3);   // 保留
      expect(out.rankTotal, 120);    // 保留
    });
    test('withRank 设置 percent', () {
      const base = AcademicScore();
      final out = base.withRank(mode: RankMode.percent, percent: 5);
      expect(out.rankMode, RankMode.percent);
      expect(out.percent, 5);
      expect(out.rank, '前 5%');
    });
  });

  group('toJson / fromJson 往返', () {
    test('percent 模式往返', () {
      const score = AcademicScore(
        gpa: 3.8, scale: 4.0, rankMode: RankMode.percent, percent: 5,
      );
      final out = AcademicScore.fromJson(score.toJson());
      expect(out.gpa, 3.8);
      expect(out.scale, 4.0);
      expect(out.rankMode, RankMode.percent);
      expect(out.percent, 5);
      expect(out.rank, '前 5%');
    });
    test('ordinal 模式往返', () {
      const score = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      final out = AcademicScore.fromJson(score.toJson());
      expect(out.rankMode, RankMode.ordinal);
      expect(out.rankPosition, 3);
      expect(out.rankTotal, 120);
      expect(out.rank, '3/120');
    });
    test('none 模式不写排名字段', () {
      const score = AcademicScore(gpa: 3.8);
      final json = score.toJson();
      expect(json.containsKey('rank_mode'), isFalse);
      expect(json.containsKey('percent'), isFalse);
      expect(json.containsKey('rank_position'), isFalse);
      expect(json.containsKey('rank_total'), isFalse);
      expect(json.containsKey('rank'), isFalse);
    });
    test('旧版只存 rank 字符串的 JSON 被忽略，rankMode 默认 none', () {
      // 开发阶段清空：旧 rank 字符串不解析
      final out = AcademicScore.fromJson({
        'gpa': 3.8,
        'rank': '前 5%',
      });
      expect(out.gpa, 3.8);
      expect(out.rankMode, RankMode.none);
      expect(out.rank, isNull);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/domain/entities/academic_score_test.dart`
Expected: FAIL — `RankMode` 未定义 / `withGpa` 等方法不存在 / 构造函数不接受新参数（编译错误）。

- [ ] **Step 3: 实现实体**

重写 `lib/domain/entities/academic_score.dart`：

```dart
/// 学业成绩：GPA + 量纲 + 排名（均可空）。排名以结构化字段存储，rank 为展示用计算 getter。
enum RankMode { none, percent, ordinal }

class AcademicScore {
  const AcademicScore({
    this.gpa,
    this.scale,
    this.rankMode = RankMode.none,
    this.percent,
    this.rankPosition,
    this.rankTotal,
  });

  final double? gpa; // 例 3.8
  final double? scale; // 量纲：4.0 / 4.3 / 4.5 / 5.0 / 100
  final RankMode rankMode;
  final int? percent; // 1..100，rankMode==percent 时有值
  final int? rankPosition; // 1..rankTotal，rankMode==ordinal 时有值
  final int? rankTotal; // >=1，rankMode==ordinal 时有值

  /// 由结构化字段生成的展示串，下游推荐/套磁读它。
  String? get rank => switch (rankMode) {
    RankMode.none => null,
    RankMode.percent => percent == null ? null : '前 $percent%',
    RankMode.ordinal =>
      (rankPosition == null || rankTotal == null) ? null : '$rankPosition/$rankTotal',
  };

  bool get isEmpty => gpa == null && scale == null && rank == null;

  AcademicScore withGpa(double? gpa) => AcademicScore(
    gpa: gpa, scale: scale, rankMode: rankMode,
    percent: percent, rankPosition: rankPosition, rankTotal: rankTotal,
  );

  AcademicScore withScale(double? scale) => AcademicScore(
    gpa: gpa, scale: scale, rankMode: rankMode,
    percent: percent, rankPosition: rankPosition, rankTotal: rankTotal,
  );

  /// mode==none 时清空三件套；mode!=none 时未传字段保留原值（?? this.x）。
  AcademicScore withRank({
    required RankMode mode,
    int? percent,
    int? rankPosition,
    int? rankTotal,
  }) {
    if (mode == RankMode.none) {
      return AcademicScore(gpa: gpa, scale: scale, rankMode: RankMode.none);
    }
    return AcademicScore(
      gpa: gpa, scale: scale, rankMode: mode,
      percent: percent ?? this.percent,
      rankPosition: rankPosition ?? this.rankPosition,
      rankTotal: rankTotal ?? this.rankTotal,
    );
  }

  Map<String, dynamic> toJson() => {
    if (gpa != null) 'gpa': gpa,
    if (scale != null) 'scale': scale,
    if (rankMode != RankMode.none) 'rank_mode': rankMode.name,
    if (percent != null) 'percent': percent,
    if (rankPosition != null) 'rank_position': rankPosition,
    if (rankTotal != null) 'rank_total': rankTotal,
  };

  factory AcademicScore.fromJson(Map<String, dynamic> json) {
    // 旧版 rank 字符串忽略（开发阶段清空）
    return AcademicScore(
      gpa: (json['gpa'] as num?)?.toDouble(),
      scale: (json['scale'] as num?)?.toDouble(),
      rankMode: _rankModeFromName(json['rank_mode']),
      percent: (json['percent'] as num?)?.toInt(),
      rankPosition: (json['rank_position'] as num?)?.toInt(),
      rankTotal: (json['rank_total'] as num?)?.toInt(),
    );
  }
}

RankMode _rankModeFromName(Object? raw) {
  final name = raw?.toString();
  for (final m in RankMode.values) {
    if (m.name == name) return m;
  }
  return RankMode.none;
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/domain/entities/academic_score_test.dart`
Expected: PASS（全部用例）。

- [ ] **Step 5: 跑 analyze**

Run: `flutter analyze lib/domain/entities/academic_score.dart`
Expected: No issues。

- [ ] **Step 6: commit**

```bash
git add lib/domain/entities/academic_score.dart test/domain/entities/academic_score_test.dart
git commit -m "feat(domain): AcademicScore 结构化排名字段 + rank 计算 getter"
```

---

### Task 2: 同步 `AcademicScoreDto`

**Files:**
- Modify: `lib/data/dto/profile_dtos.dart:7-37`（`AcademicScoreDto` 类）
- Test: `test/data/dto/profile_dtos_test.dart`（新建）

**Interfaces:**
- Consumes: Task 1 的 `AcademicScore`、`RankMode` 及其结构化字段。
- Produces: `AcademicScoreDto({double? gpa, double? scale, RankMode? rankMode, int? percent, int? rankPosition, int? rankTotal})`，`fromEntity`/`toEntity`/`toJson`/`fromJson` 对应搬运；不再有 `rank` 字段。

- [ ] **Step 1: 写失败测试**

创建 `test/data/dto/profile_dtos_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/dto/profile_dtos.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';

void main() {
  group('AcademicScoreDto 往返', () {
    test('percent 模式 entity -> dto -> entity 无损', () {
      const score = AcademicScore(
        gpa: 3.8, scale: 4.0, rankMode: RankMode.percent, percent: 5,
      );
      final dto = AcademicScoreDto.fromEntity(score);
      expect(dto.gpa, 3.8);
      expect(dto.scale, 4.0);
      expect(dto.rankMode, RankMode.percent);
      expect(dto.percent, 5);
      final back = dto.toEntity();
      expect(back.rank, '前 5%');
      expect(back.percent, 5);
    });
    test('ordinal 模式 json 往返', () {
      final dto = AcademicScoreDto.fromJson({
        'gpa': 3.8,
        'rank_mode': 'ordinal',
        'rank_position': 3,
        'rank_total': 120,
      });
      expect(dto.rankMode, RankMode.ordinal);
      expect(dto.rankPosition, 3);
      expect(dto.rankTotal, 120);
      final json = dto.toJson();
      expect(json['rank_mode'], 'ordinal');
      expect(json['rank_position'], 3);
      expect(json['rank_total'], 120);
      expect(json.containsKey('rank'), isFalse);
    });
    test('none 模式不写排名字段', () {
      const score = AcademicScore(gpa: 3.8);
      final json = AcademicScoreDto.fromEntity(score).toJson();
      expect(json.containsKey('rank_mode'), isFalse);
      expect(json.containsKey('rank'), isFalse);
    });
    test('旧版 rank 字符串被忽略', () {
      final dto = AcademicScoreDto.fromJson({'rank': '前 5%'});
      expect(dto.rankMode, isNull);
      final entity = dto.toEntity();
      expect(entity.rank, isNull);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/dto/profile_dtos_test.dart`
Expected: FAIL — `AcademicScoreDto` 无 `rankMode`/`percent` 等字段（编译错误）。

- [ ] **Step 3: 改 DTO**

替换 `lib/data/dto/profile_dtos.dart` 中 `AcademicScoreDto` 类（第 7-37 行）为：

```dart
class AcademicScoreDto {
  const AcademicScoreDto({
    this.gpa,
    this.scale,
    this.rankMode,
    this.percent,
    this.rankPosition,
    this.rankTotal,
  });

  final double? gpa;
  final double? scale;
  final RankMode? rankMode;
  final int? percent;
  final int? rankPosition;
  final int? rankTotal;

  factory AcademicScoreDto.fromJson(Map<String, dynamic> json) {
    return AcademicScoreDto(
      gpa: (json['gpa'] as num?)?.toDouble(),
      scale: (json['scale'] as num?)?.toDouble(),
      rankMode: _rankModeFromDtoName(json['rank_mode']),
      percent: (json['percent'] as num?)?.toInt(),
      rankPosition: (json['rank_position'] as num?)?.toInt(),
      rankTotal: (json['rank_total'] as num?)?.toInt(),
    );
  }

  factory AcademicScoreDto.fromEntity(AcademicScore score) {
    return AcademicScoreDto(
      gpa: score.gpa,
      scale: score.scale,
      rankMode: score.rankMode,
      percent: score.percent,
      rankPosition: score.rankPosition,
      rankTotal: score.rankTotal,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (gpa != null) 'gpa': gpa,
    if (scale != null) 'scale': scale,
    if (rankMode != null && rankMode != RankMode.none) 'rank_mode': rankMode!.name,
    if (percent != null) 'percent': percent,
    if (rankPosition != null) 'rank_position': rankPosition,
    if (rankTotal != null) 'rank_total': rankTotal,
  };

  AcademicScore toEntity() => AcademicScore(
    gpa: gpa,
    scale: scale,
    rankMode: rankMode ?? RankMode.none,
    percent: percent,
    rankPosition: rankPosition,
    rankTotal: rankTotal,
  );
}

RankMode? _rankModeFromDtoName(Object? raw) {
  final name = raw?.toString();
  for (final m in RankMode.values) {
    if (m.name == name) return m;
  }
  return null;
}
```

确认 `profile_dtos.dart` 顶部已 `import '../../domain/entities/academic_score.dart';`（第 1 行已有，无需加）。

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/data/dto/profile_dtos_test.dart`
Expected: PASS。

- [ ] **Step 5: 跑全量测试确认无回归**

Run: `flutter test`
Expected: 全绿（DTO 改动可能影响其他读 `AcademicScoreDto` 的测试，若有引用旧 `rank` 字段的会报编译错——修掉它们，见下方说明）。

> 说明：若 `flutter test` 报某处引用了 `AcademicScoreDto.rank`，搜索 `grep -rn "AcademicScoreDto" lib/ test/`，把对 `.rank` 的引用改为结构化字段。预期无引用点（DTO 主要在 `UserProfileDto` 内部使用）。

- [ ] **Step 6: 跑 analyze**

Run: `flutter analyze lib/data/dto/profile_dtos.dart`
Expected: No issues。

- [ ] **Step 7: commit**

```bash
git add lib/data/dto/profile_dtos.dart test/data/dto/profile_dtos_test.dart
git commit -m "feat(dto): AcademicScoreDto 同步结构化排名字段"
```

---

### Task 3: `LabeledTextField` 加 `errorText` 参数

**Files:**
- Modify: `lib/shared/widgets/labeled_text_field.dart`
- Test: `test/shared/widgets/labeled_text_field_test.dart`（新建）

**Interfaces:**
- Produces: `LabeledTextField` 新增可选参数 `String? errorText`，透传到 `InputDecoration.errorText`。无 `errorText` 时行为与现在完全一致（向后兼容）。

- [ ] **Step 1: 写失败测试**

创建 `test/shared/widgets/labeled_text_field_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/labeled_text_field.dart';

void main() {
  testWidgets('无 errorText 时正常渲染', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LabeledTextField(label: '字段', onChanged: _noop),
        ),
      ),
    );
    expect(find.text('字段'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('errorText 非空时显示错误文本', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LabeledTextField(
            label: '字段', onChanged: _noop, errorText: '不能为空',
          ),
        ),
      ),
    );
    expect(find.text('不能为空'), findsOneWidget);
  });

  testWidgets('输入触发 onChanged', (tester) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabeledTextField(label: '字段', onChanged: (v) => captured = v),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello');
    expect(captured, 'hello');
  });
}

void _noop(String _) {}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/shared/widgets/labeled_text_field_test.dart`
Expected: 第一条 PASS（现有行为），第二、三条可能 PASS 或 FAIL——关键是确认 `errorText` 参数尚不存在会编译错。若编译错即符合预期。

- [ ] **Step 3: 加 errorText 参数**

修改 `lib/shared/widgets/labeled_text_field.dart`。在构造函数加参数（第 6-15 行的参数列表里加 `this.errorText,`），并加字段声明，然后在 `InputDecoration` 透传：

构造函数改为：

```dart
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
    this.errorText,
  });

  final String label;
  final ValueChanged<String> onChanged;
  final String? initialValue;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;
  final Key? fieldKey;
  final String? errorText;
  ...
```

`TextField` 的 `decoration`（第 61-78 行）加 `errorText: widget.errorText,`：

```dart
          decoration: InputDecoration(
            hintText: widget.hintText,
            errorText: widget.errorText,
            filled: true,
            fillColor: AppColors.surface,
            isDense: true,
            ...
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/shared/widgets/labeled_text_field_test.dart`
Expected: PASS（三条全绿）。

- [ ] **Step 5: 跑 analyze + 全量回归**

Run: `flutter analyze lib/shared/widgets/labeled_text_field.dart && flutter test`
Expected: No issues；全量测试绿（加可选参数不破坏现有调用）。

- [ ] **Step 6: commit**

```bash
git add lib/shared/widgets/labeled_text_field.dart test/shared/widgets/labeled_text_field_test.dart
git commit -m "feat(shared): LabeledTextField 支持 errorText 错误展示"
```

---

### Task 4: 新建 `RankField` widget

**Files:**
- Create: `lib/features/profile/widgets/rank_field.dart`
- Test: `test/features/profile/widgets/rank_field_test.dart`（新建）

**Interfaces:**
- Consumes: Task 1 的 `AcademicScore`/`RankMode`/`withRank`；Task 3 的 `LabeledTextField.errorText`；现有 `ChoiceChipGroup<RankMode>`（`lib/shared/widgets/choice_chip_group.dart`，签名 `ChoiceChipGroup({required List<(T,String)> options, required T? selected, required ValueChanged<T> onSelected})`）。
- Produces: `RankField({Key? key, required AcademicScore value, required ValueChanged<AcademicScore> onChanged})`。读 `value.rankMode`/`percent`/`rankPosition`/`rankTotal`；`onChanged` 回调带新排名四件套的 `AcademicScore`（gpa/scale 保留）。

- [ ] **Step 1: 写失败测试**

创建 `test/features/profile/widgets/rank_field_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';
import 'package:scho_navi/features/profile/widgets/rank_field.dart';

void main() {
  // 受控 widget 测试脚手架：用 StatefulBuilder 把 onChanged 回调的值回喂为新的 value，
  // 否则切 chip 后父级不重建、value.rankMode 不变、输入区不会挂载，enterText 找不到框。
  Future<void> pumpRank(
    WidgetTester tester, {
    required AcademicScore value,
    required ValueChanged<AcademicScore> onChanged,
  }) async {
    AcademicScore current = value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => RankField(
                value: current,
                onChanged: (s) {
                  setState(() => current = s);
                  onChanged(s);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('初始 none 不显示输入区', (tester) async {
    await pumpRank(
      tester,
      value: const AcademicScore(),
      onChanged: (_) {},
    );
    expect(find.text('不填'), findsOneWidget);
    expect(find.byKey(const Key('rank-percent')), findsNothing);
    expect(find.byKey(const Key('rank-position')), findsNothing);
    expect(find.byKey(const Key('rank-total')), findsNothing);
  });

  testWidgets('切到百分制并输入 5 -> 回调 percent=5', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(),
      onChanged: (s) => out = s,
    );
    await tester.tap(find.text('百分制'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rank-percent')), '5');
    expect(out?.rankMode, RankMode.percent);
    expect(out?.percent, 5);
    expect(out?.rank, '前 5%');
  });

  // 以下非法输入测试直接以目标模式起步（不切 chip），避免 chip tap 触发 onChanged
  // 使 out 非空，从而能断言「非法输入不回调」。

  testWidgets('百分制输入 0 -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.percent),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-percent')), '0');
    await tester.pump(); // 刷新 setState 触发的 errorText 重建
    expect(out, isNull); // 不回调
    expect(find.text('请输入 1–100'), findsOneWidget);
  });

  testWidgets('百分制输入 101 -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.percent),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-percent')), '101');
    await tester.pump();
    expect(out, isNull);
    expect(find.text('请输入 1–100'), findsOneWidget);
  });

  testWidgets('百分制输入非数字 -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.percent),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-percent')), 'abc');
    await tester.pump();
    expect(out, isNull);
    expect(find.text('请输入 1–100'), findsOneWidget);
  });

  testWidgets('切到名次并输入 3/120 -> 回调 ordinal', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(),
      onChanged: (s) => out = s,
    );
    await tester.tap(find.text('名次'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rank-position')), '3');
    await tester.enterText(find.byKey(const Key('rank-total')), '120');
    await tester.pump();
    expect(out?.rankMode, RankMode.ordinal);
    expect(out?.rankPosition, 3);
    expect(out?.rankTotal, 120);
    expect(out?.rank, '3/120');
  });

  testWidgets('名次只填名次 -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.ordinal),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-position')), '3');
    await tester.pump();
    expect(out, isNull);
    expect(find.text('请补全名次和总人数'), findsOneWidget);
  });

  testWidgets('名次 position>total -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.ordinal),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-position')), '150');
    await tester.enterText(find.byKey(const Key('rank-total')), '120');
    await tester.pump();
    expect(out, isNull);
    expect(find.text('名次不能大于总人数'), findsOneWidget);
  });

  testWidgets('从名次切回不填 -> 回调 none 且清空', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      ),
      onChanged: (s) => out = s,
    );
    await tester.tap(find.text('不填'));
    await tester.pump();
    expect(out?.rankMode, RankMode.none);
    expect(out?.rankPosition, isNull);
    expect(out?.rankTotal, isNull);
    expect(out?.rank, isNull);
  });

  testWidgets('已有 percent 值时百分制框回填', (tester) async {
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.percent, percent: 5),
      onChanged: (_) {},
    );
    expect(find.byKey(const Key('rank-percent')), findsOneWidget);
    // 输入框初始值 5
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('rank-percent')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, '5');
  });

  testWidgets('GPA/scale 在回调中保留', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(gpa: 3.8, scale: 4.0),
      onChanged: (s) => out = s,
    );
    await tester.tap(find.text('百分制'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rank-percent')), '5');
    expect(out?.gpa, 3.8);
    expect(out?.scale, 4.0);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/profile/widgets/rank_field_test.dart`
Expected: FAIL — `RankField` 不存在 / Key `rank-percent` 等找不到（编译错或 widget tree 找不到）。

- [ ] **Step 3: 实现 RankField**

创建 `lib/features/profile/widgets/rank_field.dart`：

```dart
import 'package:flutter/material.dart';

import '../../../domain/entities/academic_score.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../../../shared/widgets/labeled_text_field.dart';

/// 专业排名输入：不填 / 百分制 / 名次 三选一，受限数字输入 + 即时校验。
/// 不合法时不回调 onChanged（外部 state 保持上一个合法值）+ errorText 标红。
class RankField extends StatelessWidget {
  const RankField({super.key, required this.value, required this.onChanged});

  final AcademicScore value;
  final ValueChanged<AcademicScore> onChanged;

  static const List<(RankMode, String)> _modes = [
    (RankMode.none, '不填'),
    (RankMode.percent, '百分制'),
    (RankMode.ordinal, '名次'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '专业排名',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ChoiceChipGroup<RankMode>(
          options: _modes,
          selected: value.rankMode,
          onSelected: (m) => onChanged(value.withRank(mode: m)),
        ),
        const SizedBox(height: 12),
        _buildInput(),
      ],
    );
  }

  Widget _buildInput() {
    switch (value.rankMode) {
      case RankMode.none:
        return const SizedBox.shrink();
      case RankMode.percent:
        return _PercentInput(value: value, onChanged: onChanged);
      case RankMode.ordinal:
        return _OrdinalInput(value: value, onChanged: onChanged);
    }
  }
}

class _PercentInput extends StatefulWidget {
  const _PercentInput({required this.value, required this.onChanged});

  final AcademicScore value;
  final ValueChanged<AcademicScore> onChanged;

  @override
  State<_PercentInput> createState() => _PercentInputState();
}

class _PercentInputState extends State<_PercentInput> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LabeledTextField(
            fieldKey: const Key('rank-percent'),
            label: '前',
            initialValue: widget.value.percent?.toString(),
            keyboardType: TextInputType.number,
            hintText: '1–100',
            errorText: _error,
            onChanged: _onChanged,
          ),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(top: 30),
          child: Text('%', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  void _onChanged(String raw) {
    final v = int.tryParse(raw.trim());
    if (v == null || v < 1 || v > 100) {
      setState(() => _error = '请输入 1–100');
      return; // 不回调
    }
    setState(() => _error = null);
    widget.onChanged(widget.value.withRank(mode: RankMode.percent, percent: v));
  }
}

class _OrdinalInput extends StatefulWidget {
  const _OrdinalInput({required this.value, required this.onChanged});

  final AcademicScore value;
  final ValueChanged<AcademicScore> onChanged;

  @override
  State<_OrdinalInput> createState() => _OrdinalInputState();
}

class _OrdinalInputState extends State<_OrdinalInput> {
  // 跟踪两个框的当前文本（LabeledTextField 自管 controller，onChanged 回传字符串）。
  late String _posText = widget.value.rankPosition?.toString() ?? '';
  late String _totalText = widget.value.rankTotal?.toString() ?? '';
  String? _posError;
  String? _totalError;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LabeledTextField(
            fieldKey: const Key('rank-position'),
            label: '第',
            initialValue: _posText,
            keyboardType: TextInputType.number,
            hintText: '名次',
            errorText: _posError,
            onChanged: (v) {
              _posText = v;
              _validate();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LabeledTextField(
            fieldKey: const Key('rank-total'),
            label: '共',
            initialValue: _totalText,
            keyboardType: TextInputType.number,
            hintText: '总人数',
            errorText: _totalError,
            onChanged: (v) {
              _totalText = v;
              _validate();
            },
          ),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(top: 30),
          child: Text('人', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  void _validate() {
    final posText = _posText.trim();
    final totalText = _totalText.trim();
    final pos = int.tryParse(posText);
    final total = int.tryParse(totalText);

    // 半填：至少一个有输入但不全 -> 提示补全，不回调
    if (posText.isEmpty || totalText.isEmpty) {
      if (posText.isNotEmpty || totalText.isNotEmpty) {
        setState(() {
          _posError = '请补全名次和总人数';
          _totalError = null;
        });
      } else {
        setState(() {
          _posError = null;
          _totalError = null;
        });
      }
      return; // 不回调
    }
    // 非数字 -> 对应框标红，不回调
    if (pos == null || total == null) {
      setState(() {
        _posError = pos == null ? '请输入数字' : null;
        _totalError = total == null ? '请输入数字' : null;
      });
      return; // 不回调
    }
    // 名次 > 总人数 -> 名次框标红，不回调
    if (pos > total) {
      setState(() {
        _posError = '名次不能大于总人数';
        _totalError = null;
      });
      return; // 不回调
    }
    // 合法 -> 清错并回调
    setState(() {
      _posError = null;
      _totalError = null;
    });
    widget.onChanged(widget.value.withRank(
      mode: RankMode.ordinal, rankPosition: pos, rankTotal: total,
    ));
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/profile/widgets/rank_field_test.dart`
Expected: PASS（全部用例）。

- [ ] **Step 5: 跑 analyze**

Run: `flutter analyze lib/features/profile/widgets/rank_field.dart`
Expected: No issues。

- [ ] **Step 6: commit**

```bash
git add lib/features/profile/widgets/rank_field.dart test/features/profile/widgets/rank_field_test.dart
git commit -m "feat(profile): RankField 结构化排名输入 + 即时校验"
```

---

### Task 5: `GpaField` 接入 `RankField`

**Files:**
- Modify: `lib/features/profile/widgets/gpa_field.dart`
- Test: `test/features/profile/widgets/gpa_field_test.dart`（扩展）

**Interfaces:**
- Consumes: Task 4 的 `RankField`；Task 1 的 `AcademicScore.withGpa`/`withScale`。
- Produces: `GpaField` 仍输出 `AcademicScore`，但排名段由 `RankField` 接管，GPA/量纲段 `onChanged` 改用 `withGpa`/`withScale` 保留排名字段。

- [ ] **Step 1: 扩展失败测试**

在 `test/features/profile/widgets/gpa_field_test.dart` 现有内容后追加（保留原 GPA 测试）：

```dart
  testWidgets('GPA 输入后排名字段保留', (tester) async {
    AcademicScore? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GpaField(
              value: const AcademicScore(
                gpa: 3.8,
                rankMode: RankMode.ordinal,
                rankPosition: 3,
                rankTotal: 120,
              ),
              onChanged: (s) => out = s,
            ),
          ),
        ),
      ),
    );
    // 改 GPA 为 3.9
    await tester.enterText(find.byKey(const Key('gpa-value')), '3.9');
    expect(out?.gpa, 3.9);
    expect(out?.rankMode, RankMode.ordinal);
    expect(out?.rankPosition, 3);
    expect(out?.rankTotal, 120);
  });

  testWidgets('排名输入后 GPA 保留', (tester) async {
    AcademicScore? out;
    AcademicScore current = const AcademicScore(gpa: 3.8, scale: 4.0);
    // 受控 widget：用 StatefulBuilder 把 onChanged 回喂为新的 value，
    // 否则切 chip 后父级不重建、rankMode 不变、百分制输入区不挂载。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => GpaField(
                value: current,
                onChanged: (s) {
                  setState(() => current = s);
                  out = s;
                },
              ),
            ),
          ),
        ),
      ),
    );
    // 切百分制并输入 5
    await tester.tap(find.text('百分制'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rank-percent')), '5');
    expect(out?.gpa, 3.8);
    expect(out?.scale, 4.0);
    expect(out?.rankMode, RankMode.percent);
    expect(out?.percent, 5);
  });
```

注意：原文件第 13 行的 `const AcademicScore()` 在新构造下仍合法（所有排名字段有默认值）。确认文件顶部已 `import 'package:scho_navi/domain/entities/academic_score.dart';`（第 3 行已有）。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/profile/widgets/gpa_field_test.dart`
Expected: FAIL — `GpaField` 仍用旧 `rank: value.rank` 重建，新追加的「GPA 输入后排名字段保留」会失败（rankMode/rankPosition 丢失）。

- [ ] **Step 3: 改 GpaField**

重写 `lib/features/profile/widgets/gpa_field.dart`：

```dart
import 'package:flutter/material.dart';

import '../../../domain/entities/academic_score.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import 'rank_field.dart';

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
          onChanged: (v) {
            final parsed = double.tryParse(v.trim());
            onChanged(value.withGpa(parsed));
          },
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
          onSelected: (s) => onChanged(value.withScale(s)),
        ),
        const SizedBox(height: 12),
        RankField(value: value, onChanged: onChanged),
      ],
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/profile/widgets/gpa_field_test.dart`
Expected: PASS（原有 + 新加用例全绿）。

- [ ] **Step 5: 跑 analyze**

Run: `flutter analyze lib/features/profile/widgets/gpa_field.dart`
Expected: No issues。

- [ ] **Step 6: commit**

```bash
git add lib/features/profile/widgets/gpa_field.dart test/features/profile/widgets/gpa_field_test.dart
git commit -m "feat(profile): GpaField 接入 RankField，onChanged 用 with* 保留排名字段"
```

---

### Task 6: 更新持久化测试 + 全量回归

**Files:**
- Modify: `test/data/local/local_profile_repository_test.dart:60,81`（构造与断言）
- 验证：`lib/data/local/local_profile_repository.dart` 无需改动（委托 `AcademicScore.fromJson/toJson`）。

**Interfaces:**
- Consumes: Task 1 的结构化 `AcademicScore` 构造与 `rank` getter。

- [ ] **Step 1: 改失败测试**

修改 `test/data/local/local_profile_repository_test.dart`：

第 60 行原 `score: AcademicScore(gpa: 3.8, scale: 4.0, rank: '前 5%'),` 改为：

```dart
        score: const AcademicScore(
          gpa: 3.8, scale: 4.0, rankMode: RankMode.percent, percent: 5,
        ),
```

第 81 行原 `expect(p.score?.rank, '前 5%');` 改为：

```dart
    expect(p.score?.rank, '前 5%');
    expect(p.score?.percent, 5);
```

并在该 test 函数末尾（第 84 行 `expect(p.research.single.role, '第一作者');` 之后）追加一条 ordinal 往返断言——但 ordinal 需要单独的 score 对象，故改为在「新字段往返」test 内的 score 之后新增一个独立 test。在第 85 行后追加：

```dart
  test('排名名次模式往返', () async {
    await repo.save(
      const UserProfile(
        name: '赵六',
        score: AcademicScore(
          gpa: 3.5,
          rankMode: RankMode.ordinal,
          rankPosition: 3,
          rankTotal: 120,
        ),
      ),
    );
    final p = repo.load();
    expect(p.score?.rankMode, RankMode.ordinal);
    expect(p.score?.rankPosition, 3);
    expect(p.score?.rankTotal, 120);
    expect(p.score?.rank, '3/120');
  });
```

确认文件顶部已 import `AcademicScore`（第 5 行已有）。`RankMode` 与 `AcademicScore` 同文件，无需额外 import。

- [ ] **Step 2: 跑测试确认通过**

Run: `flutter test test/data/local/local_profile_repository_test.dart`
Expected: PASS（旧版 JSON 兼容那条 87-102 仍绿——旧 `rank` 字符串被忽略、score 为 null 的场景不受影响；新构造用结构化字段往返正确）。

> 注：第 60 行原用 `rank: '前 5%'` 字符串构造，新构造函数已无 `rank` 参数，不改会编译错——本步即修复。

- [ ] **Step 3: 全量测试 + analyze**

Run: `flutter test && flutter analyze`
Expected: 全绿，No issues。

> 重点回归：下游 AI 推荐仓库若用 mock profile 构造 `AcademicScore(rank: ...)`，会因构造参数消失而编译错。搜索 `grep -rn "AcademicScore(" lib/ test/ | grep "rank:"`，把 `rank: '字符串'` 改为结构化字段（如 `rankMode: RankMode.percent, percent: 5`）。预期命中点：`ai_recommendation_repository` / `ai_competition_recommendation_repository` 的测试 fixture 若有。

- [ ] **Step 4: 验证下游读 rank 不变**

人工确认（读代码即可，不跑）：`lib/data/ai/ai_recommendation_repository.dart:86` 与 `lib/data/ai/ai_competition_recommendation_repository.dart:94` 仍读 `p.score!.rank`，由 getter 生成，行为不变。无需改这两个文件。

- [ ] **Step 5: commit**

```bash
git add test/data/local/local_profile_repository_test.dart
git commit -m "test(profile): 持久化测试改用结构化排名构造 + 名次往返"
```

如有下游 fixture 改动，一并 `git add` 进此 commit。

---

### Task 7: 全量验收

- [ ] **Step 1: 全量测试**

Run: `flutter test`
Expected: 全绿，测试数较改动前增加（新增实体/DTO/RankField 用例 + GpaField/持久化扩展）。

- [ ] **Step 2: analyze**

Run: `flutter analyze`
Expected: No issues found。

- [ ] **Step 3: 手动验证（可选，需模拟器）**

Run: `flutter run -d <device>`
打开个人档案编辑页，验证：
- 排名默认「不填」，无输入区
- 切「百分制」输 `5` → 显示 `前 5%`；输 `0`/`101` → 标红不生效
- 切「名次」输 `3`/`120` → 保存后重新打开仍显示 `3/120`；输 `150`/`120` → 标红
- 切「不填」→ 保存后排名为空
- 已有旧数据用户（如有）：打开后排名显示为空（旧字符串被忽略，符合开发阶段清空决定）

- [ ] **Step 4: 更新 memory**

更新 `C:\Users\xc150\.claude\projects\d--Androidprj-AIGC-LXJH-scho-navi\memory\schonavi-roadmap-status.md`：记录专业排名结构化输入已完成（如本计划全绿）。在 `MEMORY.md` 加一行索引（如未覆盖）。

- [ ] **Step 5: 最终 commit（如有 memory 更改）**

```bash
git add <memory 文件若在 repo 内；通常 memory 在用户目录，不进 repo>
# 仅当 repo 内文档有改动才 commit
```

> Memory 文件位于 `C:\Users\xc150\.claude\projects\...`，不在本 repo，无需 commit。

---

## Self-Review

**1. Spec coverage（逐条对照 spec）：**
- 二选一 + 不填（3 段切换）→ Task 4 `_modes` + ChoiceChipGroup ✓
- 百分制数字框 1–100 → Task 4 `_PercentInput` + Task 1 校验边界 ✓
- 名次两整数框 + `1≤N≤M` → Task 4 `_OrdinalInput._validate` ✓
- 新增结构化字段、`rank` 改计算 getter、下游零改动 → Task 1 + Task 6 Step 4 验证 ✓
- 旧数据清空（fromJson 忽略 rank）→ Task 1 `fromJson` + 测试 ✓
- 不填 = RankMode.none 默认 → Task 1 构造默认值 ✓
- 不合法不回调 + errorText 标红 → Task 3 errorText + Task 4 校验逻辑 ✓
- GpaField 移除排名段、接入 RankField、with* 保留字段 → Task 5 ✓
- 测试五层（实体/DTO/widget/GpaField 集成/持久化）→ Task 1/2/4/5/6 ✓

**2. Placeholder scan：** 各 Step 均含完整可落地代码，无 TBD/TODO/占位 return。Task 4 `_OrdinalInput` 为单一完整实现（含 `_posError`/`_totalError` 错误状态管理）。

**3. Type consistency：** `RankMode`、`withGpa`/`withScale`/`withRank`、`percent`/`rankPosition`/`rankTotal`、`errorText`、`RankField` 签名在各 Task 间一致。`AcademicScoreDto.rankMode` 用 `RankMode?`（DTO 可空，`toEntity` 时 `?? RankMode.none`），与 entity 的 `RankMode`（非空，默认 none）区分清晰。Key 常量 `rank-percent`/`rank-position`/`rank-total`/`gpa-value` 在测试与实现间一致。

无遗漏，计划可执行。
