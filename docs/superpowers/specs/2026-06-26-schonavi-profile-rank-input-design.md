# 专业排名结构化输入设计

日期：2026-06-26
状态：已确认，待转入实现计划

## 背景与动机

完善个人档案时，「专业排名」当前是自由文本输入（[gpa_field.dart:57-66](lib/features/profile/widgets/gpa_field.dart#L57-L66)），`AcademicScore.rank` 为 `String?`，hint 写着 `例 前 5% / 3/120`，无任何格式校验或范围校验。用户手输需要大量合法性检查，且下游可能拿到 `"前5"`、`"3/一百二十"`、`"150/120"` 等不规范或非法字符串。

目标：提供一个**必然合法**的输入方式——用户在「百分制」和「排名/全体」两种模式间二选一（或不填），通过受限的数字输入与即时校验，保证存入模型的排名数据格式正确、数值合法。

## 决策摘要

| 决策点 | 选择 |
|---|---|
| 两种输入模式关系 | 二选一（顶部单选切换，只存一种表达） |
| 百分制输入方式 | 数字框 1–100 整数，数字键盘 |
| 名次/总人数输入方式 | 两个整数框，校验 `1 ≤ 名次 ≤ 总人数` |
| 数据模型 | `AcademicScore` 新增结构化字段，`rank` 改为计算 getter（保留下游读法不变） |
| 旧数据迁移 | 开发阶段，直接清空，不做迁移（旧 `rank` 字符串在 `fromJson` 中忽略） |
| 不填排名 | 可选，`RankMode.none` 为默认，等价于「不填」 |
| 合法性强制方式 | 不合法时不回调 `onChanged`（state 保持上一个合法值）+ `errorText` 标红即时反馈 |

## 架构方案（方案 A）

顶部 3 段单选切换（不填 / 百分制 / 名次），选中哪个就只显示哪个输入区，最终只存一种表达。合法性强制到位，UI 在一个 widget 内自洽，改动集中在 profile 领域 + 一个实体，下游推荐/套磁/匹配零改动。

否决的方案：

- **方案 B（复用 ChoiceChipGroup 做模式切换）**：视觉与 GPA 量纲一致，但 3 个选项横排 chip 略占宽、「不填」作为 chip 语义稍弱。最终模式切换仍复用 `ChoiceChipGroup<RankMode>` 组件，差异主要在 A/B 是同一组件的两种用法，采纳 A 的语义。
- **方案 C（拆独立 `RankField` + 纯结构化模型）**：与「保留 `rank` 串、下游不变」的决策冲突，改动波及推荐/套磁/匹配，不采纳。

## 详细设计

### 1. 数据模型

**`AcademicScore`（[lib/domain/entities/academic_score.dart](lib/domain/entities/academic_score.dart)）扩展：**

```dart
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

  final double? gpa;
  final double? scale;
  final RankMode rankMode;
  final int? percent;        // 1..100，rankMode==percent 时有值
  final int? rankPosition;   // 1..rankTotal，rankMode==ordinal 时有值
  final int? rankTotal;      // ≥1，rankMode==ordinal 时有值

  /// 由结构化字段生成，下游推荐/套磁读它，格式：
  ///   none    -> null
  ///   percent -> "前 5%"
  ///   ordinal -> "3/120"
  String? get rank => switch (rankMode) {
    RankMode.none => null,
    RankMode.percent => percent == null ? null : '前 $percent%',
    RankMode.ordinal =>
      (rankPosition == null || rankTotal == null) ? null : '$rankPosition/$rankTotal',
  };

  bool get isEmpty => gpa == null && scale == null && rank == null;

  // copyWith 风格 helper，避免每段 onChanged 重复写一长串字段。
  // withRank 语义：mode==none 时强制把 percent/position/total 置 null（清空）；
  // mode!=none 时，传入的参数非 null 才覆盖对应字段，未传(null)的保留原值。
  // —— 因此从「名次」切到「百分制」再切回「名次」时，名次的旧数值仍在 value 里被带回。
  AcademicScore withGpa(double? gpa) =>
    AcademicScore(gpa: gpa, scale: scale, rankMode: rankMode,
                  percent: percent, rankPosition: rankPosition, rankTotal: rankTotal);

  AcademicScore withScale(double? scale) =>
    AcademicScore(gpa: gpa, scale: scale, rankMode: rankMode,
                  percent: percent, rankPosition: rankPosition, rankTotal: rankTotal);

  AcademicScore withRank({
    required RankMode mode,
    int? percent,
    int? rankPosition,
    int? rankTotal,
  }) {
    if (mode == RankMode.none) {
      // 清空三件套
      return AcademicScore(gpa: gpa, scale: scale, rankMode: RankMode.none);
    }
    return AcademicScore(
      gpa: gpa,
      scale: scale,
      rankMode: mode,
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
    // 旧版存的 rank 字符串忽略（开发阶段清空，不做迁移）
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
```

**关键点：**

- `rank` 从存储字段变成**计算 getter**，下游两个 AI 仓库的 `p.score!.rank` 调用（[ai_recommendation_repository.dart:86](lib/data/ai/ai_recommendation_repository.dart#L86)、[ai_competition_recommendation_repository.dart:94](lib/data/ai/ai_competition_recommendation_repository.dart#L94)）不变，零改动。
- `rankMode` 默认 `none`，等价于「不填」，覆盖「可选 + 不填」。
- `isEmpty` 仍以 `rank == null` 判断，行为不变。
- 持久化用结构化字段；老版本存的 `rank` 字符串在 `fromJson` 里直接忽略（开发阶段清空）。

**`AcademicScoreDto`（[lib/data/dto/profile_dtos.dart:7-37](lib/data/dto/profile_dtos.dart#L7-L37)）同步：** 增加 `rankMode` / `percent` / `rankPosition` / `rankTotal` 四个字段，`fromEntity`/`toEntity`/`toJson`/`fromJson` 对应搬运；不再存 `rank` 字符串。

### 2. UI 组件

新增 `lib/features/profile/widgets/rank_field.dart`，从 `GpaField` 移除排名那段，改为嵌入 `RankField`。

布局：

```
专业排名
[ 不填 ][ 百分制 ][ 名次 ]      ← 3 段，复用 ChoiceChipGroup<RankMode>

(选中「不填」时下方无输入区)
(选中「百分制」时):
  前 [  5  ] %                   ← 单个数字框，1–100，数字键盘
(选中「名次」时):
  第 [  3  ] 名 / 共 [ 120 ] 人  ← 两个数字框，1 ≤ 名次 ≤ 总人数
```

**组件契约：**

```dart
class RankField extends StatelessWidget {
  const RankField({super.key, required this.value, required this.onChanged});
  final AcademicScore value;            // 读 rankMode/percent/rankPosition/rankTotal
  final ValueChanged<AcademicScore> onChanged;  // 只改排名相关字段，gpa/scale 保留
}
```

**模式切换（`ChoiceChipGroup<RankMode>`）：** 选项 `(RankMode.none, '不填')` / `(RankMode.percent, '百分制')` / `(RankMode.ordinal, '名次')`。切到 `none` 时 `withRank(mode: none)` 清空 percent/position/total 并回调；切到其他模式时，未在切换回调里传入的数值字段保留在外部 state（`value`）中——因此从「名次」切到「百分制」再切回「名次」时，名次的旧数值仍由 `value` 重新带回（`withRank` 用 `?? this.x` 保留）。

**百分制输入：** 一个 `LabeledTextField`，`keyboardType: TextInputType.number`（无小数点，只要整数），`initialValue: value.percent?.toString()`。校验：

- 输入非空时 `int.tryParse`，失败 → 标红 + 不回调（state 保持上次合法值）。
- 解析成功但 `<1` 或 `>100` → 标红 + 不回调。
- 合法 → 回调 `value.withRank(mode: RankMode.percent, percent: v)`。

**名次输入：** 两个 `LabeledTextField`（名次 / 总人数），都是数字键盘。校验：

- 各自 `int.tryParse`，失败标红不回调。
- 两者都填且 `1 ≤ position ≤ total` → 回调 `value.withRank(mode: ordinal, rankPosition: p, rankTotal: t)`。
- `position > total` → 名次框 errorText「名次不能大于总人数」+ 标红 + 不回调。
- 只填了一个 → 标红提示补全 + 不回调（避免存半截数据）。

**合法性强制的核心：** 不合法时**不回调** `onChanged`，外部 state 保持上一个合法值；同时用 `errorText` 给用户即时反馈。存进 model 的永远是合法值，下游拿到的 `rank` 串必然合法。非法输入时 controller 文本保留（让用户看到自己输错了什么），仅 state 不更新。

**`GpaField` 改动（[lib/features/profile/widgets/gpa_field.dart](lib/features/profile/widgets/gpa_field.dart)）：**

- 删掉 [gpa_field.dart:56-66](lib/features/profile/widgets/gpa_field.dart#L56-L66) 那段排名 `LabeledTextField`。
- 末尾接 `RankField(value: value, onChanged: onChanged)`。
- GPA 段、量纲段的 `onChanged` 改用 `value.withGpa(parsed)` / `value.withScale(s)`，保留排名字段（当前代码只带 `rank: value.rank`，改成带结构化四件套）。

**`LabeledTextField` 最小扩展（[lib/shared/widgets/labeled_text_field.dart](lib/shared/widgets/labeled_text_field.dart)）：** 加一个可选 `errorText` 参数，透传到 `InputDecoration.errorText:`。有值时 `TextField` 自动变红边 + 下方红字。不破坏现有调用。

### 3. 校验边界 + 数据流

**校验规则汇总：**

| 模式 | 字段 | 合法条件 | 不合法时 |
|---|---|---|---|
| none | — | 恒合法 | — |
| percent | `percent` | `1 ≤ percent ≤ 100` 整数 | 标红 + 不回调 |
| ordinal | `rankPosition`, `rankTotal` | 均为正整数 且 `1 ≤ position ≤ total` | 标红 + 不回调 |
| ordinal（半填） | — | position 与 total 须同时有值 | 标红「请补全」+ 不回调 |

**数据流（名次模式填 `3/120` 为例）：**

```
RankField 名次框 onChanged("3")
  → total 暂空，标红不回调（名次框显示 3 但 state 未变）
RankField 总人数框 onChanged("120")
  → position=3, total=120, 1≤3≤120 合法
  → onChanged(AcademicScore(gpa, scale, rankMode: ordinal, rankPosition:3, rankTotal:120))
  → GpaField 透传 → ProfileController.save → LocalProfileRepository.save
  → 下次读：value.rank == "3/120"（计算 getter）
```

### 4. 测试策略

按 TDD，每个单元先写测试再写实现。

**1. 实体层 `AcademicScore`（[test/domain/entities/academic_score_test.dart](test/domain/entities/academic_score_test.dart) — 新建）**

- `rank` getter：`none`→null；`percent=5`→`'前 5%'`；`ordinal 3/120`→`'3/120'`；`percent=null`→null；`ordinal` 缺 position 或 total → null
- `isEmpty`：全空→true；只设 gpa→false；mode=none→true
- `withGpa/withScale/withRank` 保留其他字段；`withRank(mode: none)` 清空 percent/position/total
- `toJson`/`fromJson` 往返：结构化四件套存取正确；旧版只存 `rank` 字符串的 JSON → fromJson 忽略 rank、rankMode 默认 none

**2. DTO 层 `AcademicScoreDto`（[test/data/dto/profile_dtos_test.dart](test/data/dto/profile_dtos_test.dart) — 补排名字段往返）**

- `fromEntity`/`toEntity` 四件套无损搬运
- `toJson`/`fromJson` 往返
- `rank` 不再出现在 JSON 里

**3. Widget 层 `RankField`（[test/features/profile/widgets/rank_field_test.dart](test/features/profile/widgets/rank_field_test.dart) — 新建）**

- 初始 mode=none → 不显示输入区
- 切「百分制」→ 显示数字框；输 `5`→回调 `percent=5`；输 `0`/`101`/`abc`→标红不回调
- 切「名次」→ 显示两框；输 `3`+`120`→回调 `ordinal 3/120`；只填名次→标红不回调；`150/120`→标红不回调
- 切回「不填」→回调 `rankMode=none`，percent/position/total 为 null

**4. `GpaField` 集成（[test/features/profile/widgets/gpa_field_test.dart](test/features/profile/widgets/gpa_field_test.dart) — 扩展）**

- 现有 GPA 输入测试保留
- 先填排名 `3/120`，再改 GPA → 回调里 `rankPosition==3, rankTotal==120` 保留
- 先填 GPA，再切排名模式 → 回调里 `gpa` 保留

**5. 持久化（[test/data/local/local_profile_repository_test.dart:54-85](test/data/local/local_profile_repository_test.dart#L54-L85) — 改现有）**

- 第 60 行构造改为 `AcademicScore(gpa: 3.8, scale: 4.0, rankMode: RankMode.percent, percent: 5)`，断言 `p.score?.rank == '前 5%'` 且 `p.score?.percent == 5`
- 加名次模式往返：`ordinal, 3/120` → load 后 `rank == '3/120'` 且结构化字段无损
- 「旧版 JSON 兼容」（87-102 行）保留，验证旧 `rank` 字符串被忽略、不崩

**回归保护：** 跑全量 `flutter test`，确认下游 AI 推荐仓库相关测试仍绿。

## 影响范围

**改动文件：**

- `lib/domain/entities/academic_score.dart` — 扩展字段 + getter + helper + 序列化
- `lib/data/dto/profile_dtos.dart` — `AcademicScoreDto` 同步四件套
- `lib/features/profile/widgets/gpa_field.dart` — 移除排名段、接入 `RankField`、`onChanged` 用 helper
- `lib/shared/widgets/labeled_text_field.dart` — 加 `errorText` 参数
- 新增 `lib/features/profile/widgets/rank_field.dart`

**测试文件：**

- 新增 `test/domain/entities/academic_score_test.dart`
- 新增 `test/features/profile/widgets/rank_field_test.dart`
- 扩展 `test/features/profile/widgets/gpa_field_test.dart`
- 扩展/改 `test/data/local/local_profile_repository_test.dart`
- 补 `test/data/dto/profile_dtos_test.dart`（若已存在则补排名字段，否则新建）

**零改动（验证不变）：**

- `lib/data/ai/ai_recommendation_repository.dart:86` — 读 `p.score!.rank`，由 getter 生成
- `lib/data/ai/ai_competition_recommendation_repository.dart:94` — 同上
- `lib/features/profile/providers/profile_provider.dart` — 透传 `UserProfile`，不感知字段变化
