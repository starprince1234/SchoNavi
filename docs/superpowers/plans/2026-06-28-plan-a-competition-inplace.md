# Plan A: 首页竞赛原地响应 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 竞赛推荐从"提交即跳转全屏页"改为首页原地展示用户消息+思考状态+助手摘要+横滑推荐卡，与导师流视觉一致，但不做多轮对话。

**Architecture:** 抽通用 `SwipeCardCarousel<T>`（只负责分页/缩放/指示器/语义/大字体）+ 纯展示模型 `RecommendationCardData`（领域实体经 Mapper 转换，不感知 UI）。竞赛走独立异步状态机 `CompetitionHomeNotifier`（idle/loading/result/empty/error，取消旧请求+请求序号防覆盖），导师继续走 `ChatNotifier`。`MatchLevel` 改为由 `matchScore` 派生。

**Tech Stack:** Flutter, Riverpod 3.2.1（手写 provider）, Material 3, 现有 slate/indigo/cyan 冷调系统。

**关联 spec:** `docs/superpowers/specs/2026-06-28-competition-recommendation-preparation-design.md` §2(D1/D2)、§4.1、§5、§11。

## Global Constraints

- 视觉系统：沿用 `AppColors`（slate/indigo/cyan），不引入竞赛专属配色。
- 组件质量：44px 触控区、语义标签（Semantics）、大字体不溢出（375px 宽 + 文字缩放可测）。
- 不破坏导师流现有视觉与行为：`RecommendationCarousel` 的 viewport 0.86、缩放阻尼、边缘渐隐、触觉反馈全部保留。
- Riverpod 3.2.1 手写 provider，分层（domain/data/features），Mock/Result 约定。
- TDD：每个任务先写失败测试再实现。每任务结束 `flutter test` 该文件 + `flutter analyze`。
- 频繁提交：每任务一个 commit。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/shared/widgets/recommendation_card_data.dart` | 纯展示模型 + `RecommendationKind` 枚举（新建） |
| `lib/features/recommendation/mappers/recommendation_card_mapper.dart` | `Recommendation` → `RecommendationCardData`（新建） |
| `lib/features/competition_recommendation/mappers/competition_card_mapper.dart` | `RecommendedCompetition` → `RecommendationCardData`，含 `matchScore`→`MatchLevel` 派生（新建） |
| `lib/shared/widgets/swipe_card_carousel.dart` | 泛型 `SwipeCardCarousel<T>`，从 `recommendation_carousel.dart` 抽取（新建） |
| `lib/shared/widgets/swipe_recommendation_card.dart` | 改为接受 `RecommendationCardData` + 回调（修改） |
| `lib/features/chat/widgets/recommendation_carousel.dart` | 改为 `SwipeCardCarousel<Recommendation>` 的薄封装，保留导师行为（修改） |
| `lib/domain/entities/match_level.dart` | 增加 `MatchLevel.fromScore(double)`（修改） |
| `lib/features/competition_recommendation/providers/competition_home_notifier.dart` | 异步状态机（新建） |
| `lib/features/competition_recommendation/widgets/competition_home_result_view.dart` | 首页原地结果视图：用户消息+思考+摘要+横滑卡+调整条件（新建） |
| `lib/features/competition_recommendation/widgets/competition_query_understanding_card.dart` | 改用 `BentoTile`+`_KVRow` 对齐导师版（修改） |
| `lib/features/home/pages/home_page.dart` | 竞赛 tab `_submit()` 改为驱动 `CompetitionHomeNotifier` 原地渲染（修改） |

---

## Task A1: MatchLevel 由 matchScore 派生

**Files:**
- Modify: `lib/domain/entities/match_level.dart`
- Test: `test/domain/entities/match_level_test.dart`

**Interfaces:**
- Produces: `MatchLevel.fromScore(double score)` → `MatchLevel`，规则 `≥0.8 high`、`≥0.6 medium`、其余 `low`；score 被 clamp 到 [0,1]。

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/entities/match_level_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_level.dart';

void main() {
  group('MatchLevel.fromScore', () {
    test('>=0.8 -> high', () {
      expect(MatchLevel.fromScore(0.8), MatchLevel.high);
      expect(MatchLevel.fromScore(0.95), MatchLevel.high);
      expect(MatchLevel.fromScore(1.0), MatchLevel.high);
    });

    test('>=0.6 <0.8 -> medium', () {
      expect(MatchLevel.fromScore(0.6), MatchLevel.medium);
      expect(MatchLevel.fromScore(0.79), MatchLevel.medium);
    });

    test('<0.6 -> low', () {
      expect(MatchLevel.fromScore(0.59), MatchLevel.low);
      expect(MatchLevel.fromScore(0.0), MatchLevel.low);
    });

    test('clamps out-of-range', () {
      expect(MatchLevel.fromScore(1.5), MatchLevel.high);
      expect(MatchLevel.fromScore(-0.2), MatchLevel.low);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/match_level_test.dart`
Expected: FAIL — `MatchLevel.fromScore` 未定义。

- [ ] **Step 3: Write minimal implementation**

```dart
// 追加到 lib/domain/entities/match_level.dart 的 enum MatchLevel 内
  /// 由归一化匹配分派生等级：≥0.8 high、≥0.6 medium、其余 low。
  static MatchLevel fromScore(double score) {
    final s = score.clamp(0.0, 1.0);
    if (s >= 0.8) return MatchLevel.high;
    if (s >= 0.6) return MatchLevel.medium;
    return MatchLevel.low;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/entities/match_level_test.dart`
Expected: PASS（4 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/match_level.dart test/domain/entities/match_level_test.dart
git commit -m "feat(domain): MatchLevel.fromScore 由匹配分派生等级"
```

---

## Task A2: 展示模型 RecommendationCardData

**Files:**
- Create: `lib/shared/widgets/recommendation_card_data.dart`
- Test: `test/shared/widgets/recommendation_card_data_test.dart`

**Interfaces:**
- Produces: `RecommendationCardData {id, title, subtitle, tags, matchScore, matchLevel, reason, openUrl, kind}`；`RecommendationKind { mentor, competition }`。

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/widgets/recommendation_card_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/shared/widgets/recommendation_card_data.dart';

void main() {
  test('构造并派生 matchLevel', () {
    final d = RecommendationCardData(
      id: 'x',
      title: '张三',
      subtitle: '教授 / 清华大学',
      tags: const ['CV', 'NLP'],
      matchScore: 0.82,
      reason: '方向契合',
      kind: RecommendationKind.mentor,
    );
    expect(d.matchLevel, MatchLevel.high);
    expect(d.openUrl, isNull);
  });

  test('competition 带 openUrl', () {
    final d = RecommendationCardData(
      id: 'comp_icpc',
      title: 'ACM-ICPC',
      subtitle: '计算机类 / 国际级',
      tags: const ['算法编程'],
      matchScore: 0.5,
      reason: '匹配',
      openUrl: 'https://icpc.global/',
      kind: RecommendationKind.competition,
    );
    expect(d.matchLevel, MatchLevel.low);
    expect(d.openUrl, 'https://icpc.global/');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/recommendation_card_data_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/shared/widgets/recommendation_card_data.dart
import '../../domain/entities/match_level.dart';

/// 推荐卡种类。
enum RecommendationKind { mentor, competition }

/// 纯展示模型：横滑卡与列表卡共用的渲染数据。
///
/// 领域实体（Recommendation / RecommendedCompetition）经 Mapper 转换为本类，
/// 组件不感知领域；点击/收藏/打开官网等回调由父层注入。
class RecommendationCardData {
  const RecommendationCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.matchScore,
    required this.reason,
    required this.kind,
    this.openUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> tags;
  final double matchScore; // 0.0–1.0
  final String reason;
  final String? openUrl;
  final RecommendationKind kind;

  /// 由 matchScore 派生等级。
  MatchLevel get matchLevel => MatchLevel.fromScore(matchScore);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/recommendation_card_data_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/recommendation_card_data.dart test/shared/widgets/recommendation_card_data_test.dart
git commit -m "feat(shared): RecommendationCardData 展示模型"
```

---

## Task A3: 导师 Mapper

**Files:**
- Create: `lib/features/recommendation/mappers/recommendation_card_mapper.dart`
- Test: `test/features/recommendation/mappers/recommendation_card_mapper_test.dart`

**Interfaces:**
- Consumes: `Recommendation`（`lib/domain/entities/recommendation.dart`）、`RecommendationCardData`。
- Produces: `RecommendationCardData toCardData(Recommendation r)`。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/recommendation/mappers/recommendation_card_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/features/recommendation/mappers/recommendation_card_mapper.dart';
import 'package:scho_navi/shared/widgets/recommendation_card_data.dart';

void main() {
  test('映射导师卡', () {
    final r = Recommendation(
      professorId: 'p1',
      name: '张三',
      university: '清华大学',
      college: '计算机系',
      title: '教授',
      researchFields: const ['计算机视觉', '自然语言处理', '机器人'],
      matchLevel: MatchLevel.high, // 旧字段，Mapper 用 matchScore 派生
      reason: '方向高度契合',
      limitations: const [],
      homepageUrl: 'https://example.edu/p1',
      matchScore: 0.9,
    );
    final d = r.toCardData();
    expect(d.id, 'p1');
    expect(d.title, '张三');
    expect(d.subtitle, '教授 / 清华大学 / 计算机系');
    expect(d.tags, ['计算机视觉', '自然语言处理']); // take(2)
    expect(d.matchScore, 0.9);
    expect(d.matchLevel, MatchLevel.high);
    expect(d.reason, '方向高度契合');
    expect(d.openUrl, 'https://example.edu/p1');
    expect(d.kind, RecommendationKind.mentor);
  });

  test('matchScore 为 null 时回退 0', () {
    final r = Recommendation(
      professorId: 'p2',
      name: '李四',
      university: '北大',
      college: '信科',
      title: '副教授',
      researchFields: const [],
      matchLevel: MatchLevel.medium,
      reason: 'r',
      limitations: const [],
    );
    final d = r.toCardData();
    expect(d.matchScore, 0);
    expect(d.matchLevel, MatchLevel.low);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/recommendation/mappers/recommendation_card_mapper_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/recommendation/mappers/recommendation_card_mapper.dart
import '../../../domain/entities/recommendation.dart';
import '../../../shared/widgets/recommendation_card_data.dart';

/// Recommendation -> RecommendationCardData。
extension RecommendationCardMapper on Recommendation {
  RecommendationCardData toCardData() => RecommendationCardData(
        id: professorId,
        title: name,
        subtitle: '$title / $university / $college',
        tags: researchFields.take(2).toList(growable: false),
        matchScore: matchScore ?? 0,
        reason: reason,
        openUrl: homepageUrl,
        kind: RecommendationKind.mentor,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/recommendation/mappers/recommendation_card_mapper_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/recommendation/mappers/recommendation_card_mapper.dart test/features/recommendation/mappers/recommendation_card_mapper_test.dart
git commit -m "feat(recommendation): 导师卡 Mapper"
```

---

## Task A4: 竞赛 Mapper

**Files:**
- Create: `lib/features/competition_recommendation/mappers/competition_card_mapper.dart`
- Test: `test/features/competition_recommendation/mappers/competition_card_mapper_test.dart`

**Interfaces:**
- Consumes: `RecommendedCompetition`（`lib/domain/entities/recommended_competition.dart`）。
- Produces: `RecommendationCardData toCardData(RecommendedCompetition c)`。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/competition_recommendation/mappers/competition_card_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/features/competition_recommendation/mappers/competition_card_mapper.dart';
import 'package:scho_navi/shared/widgets/recommendation_card_data.dart';

RecommendedCompetition _comp({
  double score = 0.7,
  String? url = 'https://icpc.global/',
  List<String> tags = const ['算法编程', '团队赛', '高强度训练'],
}) =>
    RecommendedCompetition(
      id: 'comp_icpc',
      name: 'ACM-ICPC',
      category: '计算机类',
      level: '国际级',
      tags: tags,
      teamSize: '3 人团队',
      signupTime: '约每年 4 月',
      contestTime: '9-12 月',
      format: '5 小时算法编程',
      organizer: 'ACM',
      officialUrl: url,
      reason: '方向契合',
      preparationTips: const [],
      limitations: const [],
      matchScore: score,
    );

void main() {
  test('映射竞赛卡：subtitle=类别/级别，tags take(2)，openUrl=officialUrl', () {
    final d = _comp().toCardData();
    expect(d.id, 'comp_icpc');
    expect(d.title, 'ACM-ICPC');
    expect(d.subtitle, '计算机类 / 国际级');
    expect(d.tags, ['算法编程', '团队赛']);
    expect(d.matchScore, 0.7);
    expect(d.matchLevel, MatchLevel.medium);
    expect(d.openUrl, 'https://icpc.global/');
    expect(d.kind, RecommendationKind.competition);
  });

  test('officialUrl 为 null 时 openUrl 为 null', () {
    final d = _comp(url: null).toCardData();
    expect(d.openUrl, isNull);
  });

  test('tags 少于 2 个时不补齐', () {
    final d = _comp(tags: const ['算法编程']).toCardData();
    expect(d.tags, ['算法编程']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/competition_recommendation/mappers/competition_card_mapper_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/competition_recommendation/mappers/competition_card_mapper.dart
import '../../../domain/entities/recommended_competition.dart';
import '../../../shared/widgets/recommendation_card_data.dart';

/// RecommendedCompetition -> RecommendationCardData。
extension CompetitionCardMapper on RecommendedCompetition {
  RecommendationCardData toCardData() => RecommendationCardData(
        id: id,
        title: name,
        subtitle: '$category / $level',
        tags: tags.take(2).toList(growable: false),
        matchScore: matchScore,
        reason: reason,
        openUrl: officialUrl,
        kind: RecommendationKind.competition,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/competition_recommendation/mappers/competition_card_mapper_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/competition_recommendation/mappers/competition_card_mapper.dart test/features/competition_recommendation/mappers/competition_card_mapper_test.dart
git commit -m "feat(competition): 竞赛卡 Mapper"
```

---

## Task A5: SwipeRecommendationCard 改为接受展示模型

**Files:**
- Modify: `lib/shared/widgets/swipe_recommendation_card.dart`
- Test: `test/shared/widgets/swipe_recommendation_card_test.dart`

**Interfaces:**
- Consumes: `RecommendationCardData`、`BentoTile`、`MatchLevelChip`、`AppColors`、`Haptics`。
- Produces: `SwipeRecommendationCard({required RecommendationCardData data, required VoidCallback onTap, bool isFavorite, VoidCallback? onFavoritePressed, VoidCallback? onOpenUrlPressed})`。

注意：当前 `SwipeRecommendationCard` 用 `_CompactFields` 渲染导师的 `researchFields`；改为通用后用 `data.tags`（竞赛和导师都通过 Mapper 产出 tags）。`onOpenHomepagePressed` 改名 `onOpenUrlPressed`，按钮文案根据 `data.kind`：导师"访问主页"、竞赛"访问官网"。

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/widgets/swipe_recommendation_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/recommendation_card_data.dart';
import 'package:scho_navi/shared/widgets/swipe_recommendation_card.dart';

RecommendationCardData _data(RecommendationKind kind) => RecommendationCardData(
      id: 'x',
      title: '标题',
      subtitle: '副标题',
      tags: const ['标签A', '标签B'],
      matchScore: 0.8,
      reason: '理由理由理由理由理由',
      openUrl: kind == RecommendationKind.competition ? 'https://x' : null,
      kind: kind,
    );

void main() {
  testWidgets('导师卡渲染标题/副标题/标签/理由，无官网按钮', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwipeRecommendationCard(
          data: _data(RecommendationKind.mentor),
          onTap: () {},
        ),
      ),
    ));
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('副标题'), findsOneWidget);
    expect(find.text('标签A'), findsOneWidget);
    expect(find.text('理由理由理由理由理由'), findsOneWidget);
    expect(find.text('访问主页'), findsNothing); // 无 onOpenUrlPressed
  });

  testWidgets('竞赛卡有 onOpenUrlPressed 时显示访问官网', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwipeRecommendationCard(
          data: _data(RecommendationKind.competition),
          onTap: () {},
          onOpenUrlPressed: () {},
        ),
      ),
    ));
    expect(find.text('访问官网'), findsOneWidget);
  });

  testWidgets('onTap 触发回调', (t) async {
    var tapped = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwipeRecommendationCard(
          data: _data(RecommendationKind.mentor),
          onTap: () => tapped = true,
        ),
      ),
    ));
    await t.tap(find.text('标题'));
    await t.pump();
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/swipe_recommendation_card_test.dart`
Expected: FAIL — `SwipeRecommendationCard` 仍接受 `recommendation`。

- [ ] **Step 3: Write minimal implementation**

重写 `lib/shared/widgets/swipe_recommendation_card.dart`：把 `final Recommendation recommendation;` 改为 `final RecommendationCardData data;`，删除 `import recommendation.dart`，加 `import recommendation_card_data.dart`。build 内 `final r = widget.data;`，`r.name`→`r.title`、`r.title`（职称）→ 不再有，subtitle 直接显示 `r.subtitle`（去掉学校行那段 Row，或保留为 subtitle）。`MatchLevelChip(level: r.matchLevel, matchScore: r.matchScore)`。`_CompactFields(fields: r.researchFields)`→`_CompactFields(fields: r.tags)`。官网按钮文案：`data.kind == RecommendationKind.mentor ? '访问主页' : '访问官网'`。

关键替换片段：

```dart
class SwipeRecommendationCard extends StatefulWidget {
  const SwipeRecommendationCard({
    super.key,
    required this.data,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoritePressed,
    this.onOpenUrlPressed,
  });

  final RecommendationCardData data;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onOpenUrlPressed;
  ...
}
```

build 内头部行简化为 `title` + `subtitle` + `MatchLevelChip`（移除原"学校行"Row，因为 subtitle 已含学校）。其余结构（cyan 理由竖条、底部按钮行、按下态动画、LayoutBuilder 兜底高度）保持不变。官网按钮：

```dart
TextButton.icon(
  style: TextButton.styleFrom(
    minimumSize: const Size(44, 44),
    foregroundColor: AppColors.cyan,
    iconColor: AppColors.cyan,
  ),
  onPressed: () { Haptics.light(); widget.onOpenUrlPressed!(); },
  icon: const Icon(Icons.open_in_new, size: 16),
  label: Text(widget.data.kind == RecommendationKind.mentor ? '访问主页' : '访问官网'),
),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/swipe_recommendation_card_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Run any callers' tests to catch breakage**

Run: `flutter test test/features/chat/`
Expected: 现有 chat 卡片测试可能 FAIL（因为 `RecommendationCarousel` 还传 `recommendation`）。这是预期的——Task A6 修复。若 chat 测试此时已坏，记录在本任务 commit 里说明"A6 修复"。

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/swipe_recommendation_card.dart test/shared/widgets/swipe_recommendation_card_test.dart
git commit -m "refactor(shared): SwipeRecommendationCard 改用展示模型"
```

---

## Task A6: 抽取泛型 SwipeCardCarousel<T>，导师 RecommendationCarousel 复用

**Files:**
- Create: `lib/shared/widgets/swipe_card_carousel.dart`
- Modify: `lib/features/chat/widgets/recommendation_carousel.dart`
- Test: `test/shared/widgets/swipe_card_carousel_test.dart`
- Modify: `test/features/chat/` 下相关测试（按需）

**Interfaces:**
- Produces: `SwipeCardCarousel<T>({required List<T> items, required Widget Function(BuildContext, T, int) itemBuilder, required String Function(T) semanticsLabel, double? height})`。内部负责 PageController、viewportFraction 0.86、缩放阻尼（scale 0.92/opacity 0.55）、边缘渐隐、胶囊指示器（active 20 / inactive 6）、`Haptics.selection`、Semantics（label=`第 N 张，共 M 张，<semanticsLabel(item)>`）、大字体高度自适应（250 + textScale*54）。`items` 为空返回 `SizedBox.shrink()`；≤1 张隐藏指示器与边缘渐隐。

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/widgets/swipe_card_carousel_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/swipe_card_carousel.dart';

void main() {
  testWidgets('空列表渲染空', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwipeCardCarousel<String>(
          items: const [],
          itemBuilder: (_, s, __) => Text(s),
          semanticsLabel: (s) => s,
        ),
      ),
    ));
    expect(find.byType(SwipeCardCarousel<String>), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('3 项渲染 3 张 + 指示器', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: SwipeCardCarousel<String>(
            items: const ['a', 'b', 'c'],
            itemBuilder: (_, s, __) => Text(s),
            semanticsLabel: (s) => s,
          ),
        ),
      ),
    ));
    expect(find.text('a'), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsNWidgets(3)); // 指示器 AnimatedContainer 无图标，改断言数量
  });

  testWidgets('单张无指示器', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: SwipeCardCarousel<String>(
            items: const ['only'],
            itemBuilder: (_, s, __) => Text(s),
            semanticsLabel: (s) => s,
          ),
        ),
      ),
    ));
    // 指示器在 items.length>1 时才生成；单张不渲染指示器 Row。
    expect(find.text('only'), findsOneWidget);
  });
}
```

注：指示器是 `AnimatedContainer`，上面用 `find.byIcon` 仅作占位，实现后按实际 DOM 调整为 `find.byType(AnimatedContainer)` 数量断言。实施时以"指示器数量 == items.length 且单张为 0"为准。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/swipe_card_carousel_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

把 `recommendation_carousel.dart` 的 PageView/缩放/边缘渐隐/指示器逻辑整体迁到 `lib/shared/widgets/swipe_card_carousel.dart`，泛型化：

```dart
// lib/shared/widgets/swipe_card_carousel.dart
import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';

/// 通用横滑卡轨道：分页/缩放/胶囊指示器/边缘渐隐/触觉/语义/大字体自适应。
/// 卡片内容由 [itemBuilder] 提供，组件不感知数据类型。
class SwipeCardCarousel<T> extends StatefulWidget {
  const SwipeCardCarousel({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.semanticsLabel,
    this.height,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String Function(T item) semanticsLabel;
  final double? height;

  @override
  State<SwipeCardCarousel<T>> createState() => _SwipeCardCarouselState<T>();
}

class _SwipeCardCarouselState<T> extends State<SwipeCardCarousel<T>> {
  late final PageController _controller;
  double _pageFloat = 0;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.86);
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final page = _controller.hasClients ? (_controller.page ?? 0.0) : 0.0;
    if ((page - _pageFloat).abs() < 0.001) return;
    setState(() => _pageFloat = page);
  }

  @override
  void didUpdateWidget(covariant SwipeCardCarousel<T> old) {
    super.didUpdateWidget(old);
    if (widget.items.isEmpty) { _page = 0; return; }
    final maxPage = widget.items.length - 1;
    if (_page <= maxPage) return;
    _page = maxPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(_page);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  ({double scale, double opacity}) _dampFor(int index) {
    final delta = (index - _pageFloat).abs();
    if (delta >= 1) return (scale: 0.92, opacity: 0.55);
    final t = delta;
    return (scale: 1 - (1 - 0.92) * t, opacity: 1 - (1 - 0.55) * t);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = AppColors.paperOf(isDark);
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final h = widget.height ?? (250 + (textScale - 1).clamp(0, 1) * 54);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(children: [
          SizedBox(
            height: h,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) { Haptics.selection(); if (mounted) setState(() => _page = i); },
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final d = _dampFor(index);
                return Semantics(
                  label: '第 ${index + 1} 张，共 ${widget.items.length} 张，'
                      '${widget.semanticsLabel(widget.items[index])}',
                  container: true,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AnimatedScale(
                      scale: d.scale,
                      duration: const Duration(milliseconds: 60),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 60),
                        opacity: d.opacity,
                        child: widget.itemBuilder(context, widget.items[index], index),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.items.length > 1)
            Positioned.fill(child: IgnorePointer(child: Row(children: [
              _EdgeFade(color: paperColor, side: _EdgeSide.left),
              const Spacer(),
              _EdgeFade(color: paperColor, side: _EdgeSide.right),
            ]))),
        ]),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                key: Key('carousel-indicator-$i'),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active ? AppColors.indigo : scheme.outline.withValues(alpha: 0.4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

enum _EdgeSide { left, right }

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.color, required this.side});
  final Color color;
  final _EdgeSide side;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: side == _EdgeSide.left ? Alignment.centerLeft : Alignment.centerRight,
          end: side == _EdgeSide.left ? Alignment.centerRight : Alignment.centerLeft,
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
```

然后 `recommendation_carousel.dart` 改为薄封装（保留导师收藏 watch 与回调注入）：

```dart
// lib/features/chat/widgets/recommendation_carousel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../domain/entities/favorite_item.dart';
import '../../../domain/entities/recommendation.dart';
import '../../../features/recommendation/mappers/recommendation_card_mapper.dart';
import '../../../shared/widgets/recommendation_card_data.dart';
import '../../../shared/widgets/swipe_card_carousel.dart';
import '../../../shared/widgets/swipe_recommendation_card.dart';

/// 导师横滑轨道：SwipeCardCarousel + 导师收藏 watch 与回调注入。
class RecommendationCarousel extends ConsumerWidget {
  const RecommendationCarousel({
    super.key,
    required this.recommendations,
    required this.onTap,
    this.onOpenHomepage,
    this.height,
  });

  final List<Recommendation> recommendations;
  final void Function(String professorId) onTap;
  final void Function(Recommendation recommendation)? onOpenHomepage;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwipeCardCarousel<Recommendation>(
      items: recommendations,
      height: height,
      semanticsLabel: (r) => '${r.name}，${r.university}',
      itemBuilder: (context, r, _) {
        final isFavorite = ref
            .watch(favoriteStatusProvider(r.professorId))
            .maybeWhen(data: (v) => v, orElse: () => false);
        return SwipeRecommendationCard(
          data: r.toCardData(),
          isFavorite: isFavorite,
          onTap: () => onTap(r.professorId),
          onFavoritePressed: () => ref
              .read(favoriteRepositoryProvider)
              .toggle(FavoriteItem.fromRecommendation(r)),
          onOpenUrlPressed: onOpenHomepage == null ? null : () => onOpenHomepage!(r),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/swipe_card_carousel_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Run导师流相关测试，修复断言**

Run: `flutter test test/features/chat/`
Expected: 修复任何因 `SwipeRecommendationCard` 参数变更导致的编译/断言错误（旧测试若直接构造 `SwipeRecommendationCard(recommendation:...)` 需改为 `data: r.toCardData()`）。逐个修复至 PASS。

- [ ] **Step 6: Run full chat + shared test suites**

Run: `flutter test test/features/chat/ test/shared/`
Expected: PASS。

- [ ] **Step 7: Commit**

```bash
git add lib/shared/widgets/swipe_card_carousel.dart lib/features/chat/widgets/recommendation_carousel.dart test/shared/widgets/swipe_card_carousel_test.dart test/features/chat/
git commit -m "refactor(shared): 抽 SwipeCardCarousel 泛型轨道，导师流复用"
```

---

## Task A7: CompetitionQueryUnderstandingCard 升级为 BentoTile

**Files:**
- Modify: `lib/features/competition_recommendation/widgets/competition_query_understanding_card.dart`
- Test: `test/features/competition_recommendation/widgets/competition_query_understanding_card_test.dart`

先读现有文件了解字段：`CompetitionQueryUnderstanding { directions, categories, timingPreferences, teamPreferences, uncertainties }`。

**Interfaces:**
- Consumes: `CompetitionQueryUnderstanding`、`BentoTile`、`AppColors`。
- Produces: 与导师版 `QueryUnderstandingCard` 同构的 Bento 卡（auto_awesome 头 + _KVRow）。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/competition_recommendation/widgets/competition_query_understanding_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/competition_query_understanding.dart';
import 'package:scho_navi/features/competition_recommendation/widgets/competition_query_understanding_card.dart';

void main() {
  testWidgets('渲染 AI 标题 + 键值行 + 待确认', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CompetitionQueryUnderstandingCard(
          understanding: CompetitionQueryUnderstanding(
            directions: const ['算法'],
            categories: const ['计算机类'],
            timingPreferences: const ['近期'],
            teamPreferences: const ['个人'],
            uncertainties: const ['是否需要组队'],
          ),
        ),
      ),
    ));
    expect(find.text('我理解到的需求'), findsOneWidget);
    expect(find.text('算法'), findsOneWidget);
    expect(find.text('计算机类'), findsOneWidget);
    expect(find.text('待确认：'), findsOneWidget);
    expect(find.text('· 是否需要组队'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/competition_recommendation/widgets/competition_query_understanding_card_test.dart`
Expected: FAIL — 当前用 Material Card，无"我理解到的需求"标题或断言不匹配。

- [ ] **Step 3: Write minimal implementation**

重写为基于 `BentoTile` 的结构，键值行复用导师版 `_KVRow` 模式（在本文件内定义一份私有 `_KVRow`，与 `query_understanding_card.dart` 同实现，避免跨文件依赖私有类）：

```dart
// lib/features/competition_recommendation/widgets/competition_query_understanding_card.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/competition_query_understanding.dart';
import '../../../shared/widgets/bento_tile.dart';

class CompetitionQueryUnderstandingCard extends StatelessWidget {
  const CompetitionQueryUnderstandingCard({super.key, required this.understanding});

  final CompetitionQueryUnderstanding understanding;

  @override
  Widget build(BuildContext context) {
    final u = understanding;
    final textTheme = Theme.of(context).textTheme;
    String join(List<String> xs) => xs.isEmpty ? '暂无信息' : xs.join('、');
    return BentoTile(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.auto_awesome, size: 18, color: AppColors.indigo),
            SizedBox(width: 8),
          ]),
          // ... 见下方说明：标题用 Text('我理解到的需求')
          // _KVRow(label:'方向', value: join(u.directions))
          // _KVRow(label:'类别', value: join(u.categories))
          // _KVRow(label:'时间', value: join(u.timingPreferences))
          // _KVRow(label:'组队', value: join(u.teamPreferences))
          // if uncertainties 不空：待确认区
        ],
      ),
    );
  }
}
```

完整实现按导师版 `QueryUnderstandingCard` 的结构补齐（auto_awesome 图标 + Text('我理解到的需求') + 4 个 _KVRow + 待确认区）。`_KVRow` 私有类复制导师版实现。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/competition_recommendation/widgets/competition_query_understanding_card_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/features/competition_recommendation/widgets/competition_query_understanding_card.dart test/features/competition_recommendation/widgets/competition_query_understanding_card_test.dart
git commit -m "refactor(competition): 需求理解卡升级为 BentoTile 键值布局"
```

---

## Task A8: CompetitionHomeNotifier 异步状态机

**Files:**
- Create: `lib/features/competition_recommendation/providers/competition_home_notifier.dart`
- Test: `test/features/competition_recommendation/providers/competition_home_notifier_test.dart`

**Interfaces:**
- Consumes: `CompetitionRecommendationRepository`（`getRecommendations({required prompt, UserProfile? profile})` → `Result<CompetitionRecommendationResult>`）、`profileProvider`、`historyRepositoryProvider`。
- Produces: `CompetitionHomeState`（sealed/类：`idle | loading | result(data) | empty | error(message)`）；`CompetitionHomeNotifier extends Notifier<CompetitionHomeState>`；provider `competitionHomeProvider`；方法 `Future<void> submit(String prompt)`、`void reset()`。
- 竞态：维护 `_requestSeq`，每次 submit 自增；回调时若 seq 不匹配则丢弃。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/competition_recommendation/providers/competition_home_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition_query_understanding.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/competition_recommendation_repository.dart';
import 'package:scho_navi/features/competition_recommendation/providers/competition_home_notifier.dart';

class _FakeRepo implements CompetitionRecommendationRepository {
  _FakeRepo(this._outcome);
  final Result<CompetitionRecommendationResult> _outcome;
  int calls = 0;
  @override
  Future<Result<CompetitionRecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
  }) async {
    calls++;
    return _outcome;
  }
}

CompetitionRecommendationResult _result(int n) => CompetitionRecommendationResult(
      sessionId: 's1',
      understanding: CompetitionQueryUnderstanding(
        directions: const [], categories: const [],
        timingPreferences: const [], teamPreferences: const [], uncertainties: const [],
      ),
      recommendations: List.generate(n, (i) => RecommendedCompetition(
        id: 'c$i', name: 'C$i', category: '计算机类', level: '国家级',
        tags: const [], teamSize: '个人', signupTime: '', contestTime: '',
        format: '', organizer: '', officialUrl: null, reason: '', preparationTips: const [], limitations: const [], matchScore: 0.5,
      )),
      followUpQuestions: const [],
    );

void main() {
  test('submit 成功进入 result', () async {
    final container = ProviderContainer(overrides: [
      competitionRecommendationRepositoryProvider.overrideWithValue(
        _FakeRepo(Success(_result(2))),
      ),
    ]);
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('我想参加算法竞赛');
    final s = container.read(competitionHomeProvider);
    expect(s, isA<CompetitionHomeResult>());
    expect((s as CompetitionHomeResult).data.recommendations.length, 2);
  });

  test('空结果进入 empty', () async {
    final container = ProviderContainer(overrides: [
      competitionRecommendationRepositoryProvider.overrideWithValue(
        _FakeRepo(Success(_result(0))),
      ),
    ]);
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('x');
    expect(container.read(competitionHomeProvider), isA<CompetitionHomeEmpty>());
  });

  test('失败进入 error', () async {
    final container = ProviderContainer(overrides: [
      competitionRecommendationRepositoryProvider.overrideWithValue(
        _FakeRepo(Failure(Exception('boom'))),
      ),
    ]);
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('x');
    expect(container.read(competitionHomeProvider), isA<CompetitionHomeError>());
  });

  test('reset 回到 idle', () async {
    final container = ProviderContainer(overrides: [
      competitionRecommendationRepositoryProvider.overrideWithValue(
        _FakeRepo(Success(_result(1))),
      ),
    ]);
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('x');
    container.read(competitionHomeProvider.notifier).reset();
    expect(container.read(competitionHomeProvider), isA<CompetitionHomeIdle>());
  });

  test('竞态：后一次 submit 覆盖前一次', () async {
    final slow = _FakeRepo(Success(_result(1)));
    // 用两个 repo 模拟顺序：通过单 repo 两次调用，靠 seq 机制保证最后状态匹配最后结果。
    final container = ProviderContainer(overrides: [
      competitionRecommendationRepositoryProvider.overrideWithValue(slow),
    ]);
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('a');
    await container.read(competitionHomeProvider.notifier).submit('b');
    // 两次都完成，最终状态为最后一次的结果。
    expect(container.read(competitionHomeProvider), isA<CompetitionHomeResult>());
    expect(slow.calls, 2);
  });
}
```

注：`Success`/`Failure` 来自 `core/result/result.dart`，按现有 `Result` 模式确认构造器名（参考 `competition_recommendation_provider.dart` 的 `Success(:final data)` / `Failure(:final error)` 解构用法）。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/competition_recommendation/providers/competition_home_notifier_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/competition_recommendation/providers/competition_home_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/competition_recommendation_result.dart';
import '../../profile/providers/profile_provider.dart';

sealed class CompetitionHomeState {
  const CompetitionHomeState();
}
class CompetitionHomeIdle extends CompetitionHomeState { const CompetitionHomeIdle(); }
class CompetitionHomeLoading extends CompetitionHomeState {
  final String prompt;
  const CompetitionHomeLoading(this.prompt);
}
class CompetitionHomeResult extends CompetitionHomeState {
  final CompetitionRecommendationResult data;
  const CompetitionHomeResult(this.data);
}
class CompetitionHomeEmpty extends CompetitionHomeState { const CompetitionHomeEmpty(); }
class CompetitionHomeError extends CompetitionHomeState {
  final String message;
  const CompetitionHomeError(this.message);
}

class CompetitionHomeNotifier extends Notifier<CompetitionHomeState> {
  int _seq = 0;

  @override
  CompetitionHomeState build() => const CompetitionHomeIdle();

  Future<void> submit(String prompt) async {
    final mySeq = ++_seq;
    state = CompetitionHomeLoading(prompt);
    final profile = ref.read(profileProvider);
    final repo = ref.read(competitionRecommendationRepositoryProvider);
    final result = await repo.getRecommendations(prompt: prompt, profile: profile);
    if (mySeq != _seq) return; // 过期请求丢弃
    state = switch (result) {
      Success(:final data) => data.recommendations.isEmpty
          ? const CompetitionHomeEmpty()
          : CompetitionHomeResult(data),
      Failure(:final error) => CompetitionHomeError(error.toString()),
    };
  }

  void reset() {
    _seq++;
    state = const CompetitionHomeIdle();
  }
}

final competitionHomeProvider =
    NotifierProvider<CompetitionHomeNotifier, CompetitionHomeState>(
  CompetitionHomeNotifier.new,
);
```

（history 写入由视图层在 result 态触发，或在 notifier 内 unawaited 调用 `historyRepositoryProvider.addFromCompetitionResult`——参考现有 `competitionRecommendationProvider`。为保持与现有行为一致，在 Success 分支内 `unawaited(ref.read(historyRepositoryProvider).addFromCompetitionResult(...))`。）

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/competition_recommendation/providers/competition_home_notifier_test.dart`
Expected: PASS（5 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/competition_recommendation/providers/competition_home_notifier.dart test/features/competition_recommendation/providers/competition_home_notifier_test.dart
git commit -m "feat(competition): CompetitionHomeNotifier 异步状态机"
```

---

## Task A9: 首页原地结果视图 CompetitionHomeResultView

**Files:**
- Create: `lib/features/competition_recommendation/widgets/competition_home_result_view.dart`
- Test: `test/features/competition_recommendation/widgets/competition_home_result_view_test.dart`

**Interfaces:**
- Consumes: `CompetitionHomeState`、`SwipeCardCarousel<RecommendationCardData>`、`SwipeRecommendationCard`、`CompetitionQueryUnderstandingCard`、`competitionCardMapper`、`linkLauncherProvider`、`AppRouter`（`context.push('/competition/:id')`）。
- Produces: `CompetitionHomeResultView` widget，根据 state 渲染：
  - `idle`：空（父层显示输入态）
  - `loading`：用户消息气泡 + 思考占位（`auto_awesome` + "正在为你匹配竞赛…"，shimmer 或简单加载文案）
  - `result`：用户消息 + 助手摘要（一句话，基于 understanding 拼接）+ `CompetitionQueryUnderstandingCard` + `SwipeCardCarousel<RecommendationCardData>`（item 用 `SwipeRecommendationCard(data: c.toCardData(), onTap: 详情, onOpenUrlPressed: 官网)`）+ "调整条件"按钮（触发 reset）
  - `empty`：用户消息 + "暂无匹配竞赛，试试调整条件"+ "调整条件"
  - `error`：用户消息 + 错误文案 + "重试"（重新 submit 同 prompt，需父层传入 onRetry）

构造：`CompetitionHomeResultView({required CompetitionHomeState state, required VoidCallback onAdjust, required Future<void> Function(String) onRetry, required prompt})`。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/competition_recommendation/widgets/competition_home_result_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/competition_query_understanding.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/features/competition_recommendation/providers/competition_home_notifier.dart';
import 'package:scho_navi/features/competition_recommendation/widgets/competition_home_result_view.dart';

CompetitionRecommendationResult _res(int n) => CompetitionRecommendationResult(
      sessionId: 's', understanding: CompetitionQueryUnderstanding(
        directions: const ['算法'], categories: const ['计算机类'],
        timingPreferences: const [], teamPreferences: const [], uncertainties: const [],
      ),
      recommendations: List.generate(n, (i) => RecommendedCompetition(
        id: 'c$i', name: '竞赛$i', category: '计算机类', level: '国家级',
        tags: const ['算法'], teamSize: '个人', signupTime: '', contestTime: '',
        format: '', organizer: '', officialUrl: 'https://x', reason: '契合', preparationTips: const [], limitations: const [], matchScore: 0.7,
      )),
      followUpQuestions: const [],
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('loading 显示思考占位', (t) async {
    await t.pumpWidget(_wrap(CompetitionHomeResultView(
      state: const CompetitionHomeLoading('我想参加算法竞赛'),
      onAdjust: () {}, onRetry: (_) async {},
    )));
    expect(find.text('我想参加算法竞赛'), findsOneWidget); // 用户消息
    expect(find.textContaining('匹配'), findsWidgets); // 思考文案
  });

  testWidgets('result 显示摘要+横滑卡+调整条件', (t) async {
    await t.pumpWidget(_wrap(CompetitionHomeResultView(
      state: CompetitionHomeResult(_res(2)),
      onAdjust: () {}, onRetry: (_) async {},
    )));
    expect(find.text('我理解到的需求'), findsOneWidget);
    expect(find.text('竞赛0'), findsOneWidget);
    expect(find.text('调整条件'), findsOneWidget);
  });

  testWidgets('empty 显示调整条件', (t) async {
    await t.pumpWidget(_wrap(CompetitionHomeResultView(
      state: const CompetitionHomeEmpty(),
      onAdjust: () {}, onRetry: (_) async {},
    )));
    expect(find.textContaining('暂无'), findsOneWidget);
    expect(find.text('调整条件'), findsOneWidget);
  });

  testWidgets('error 显示重试', (t) async {
    await t.pumpWidget(_wrap(CompetitionHomeResultView(
      state: const CompetitionHomeError('出错了'),
      onAdjust: () {}, onRetry: (_) async {},
    )));
    expect(find.text('重试'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/competition_recommendation/widgets/competition_home_result_view_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

实现 `CompetitionHomeResultView`，按 state 分支渲染。用户消息用现有 `ChatMessageBubble`（若可复用导师用户气泡；先读 `lib/features/chat/widgets/chat_message_bubble.dart` 确认构造签名，若强耦合导师消息则在本视图内用一个简单的右对齐气泡容器 + AppColors.indigoSoft 背景）。横滑卡用 `SwipeCardCarousel<RecommendationCardData>(items: recs.map((c)=>c.toCardData()).toList(), itemBuilder: (_, d, __) => SwipeRecommendationCard(data: d, onTap: ()=>onOpenDetail(d.id), onOpenUrlPressed: d.openUrl==null?null:()=>launch(d.openUrl)), semanticsLabel: (d)=>d.title)`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/competition_recommendation/widgets/competition_home_result_view_test.dart`
Expected: PASS（4 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/competition_recommendation/widgets/competition_home_result_view.dart test/features/competition_recommendation/widgets/competition_home_result_view_test.dart
git commit -m "feat(competition): 首页原地结果视图"
```

---

## Task A10: 首页竞赛 tab 接入原地响应

**Files:**
- Modify: `lib/features/home/pages/home_page.dart:135-192`（`_submit`）及周边状态
- Modify: `lib/features/home/pages/home_page.dart:444-453`（tab 切换）与竞赛态渲染区
- Test: `test/features/home/home_page_competition_inplace_test.dart`（新建）

**Interfaces:**
- Consumes: `competitionHomeProvider`、`CompetitionHomeResultView`、`AppRouter`。
- 改动：竞赛 tab 提交不再 `context.push('/competition-recommendation')`，而是 `ref.read(competitionHomeProvider.notifier).submit(prompt)`，并切到"对话态"渲染 `CompetitionHomeResultView`。`_inConversation` 概念扩展到竞赛 tab（或新增 `_inCompetitionResult` 标志）。"调整条件"= `reset()` + 退出对话态回输入态。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/home/home_page_competition_inplace_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition_query_understanding.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/competition_recommendation_repository.dart';
import 'package:scho_navi/features/home/pages/home_page.dart';

class _FakeRepo implements CompetitionRecommendationRepository {
  @override
  Future<Result<CompetitionRecommendationResult>> getRecommendations({
    required String prompt, UserProfile? profile,
  }) async => Success(CompetitionRecommendationResult(
      sessionId: 's', understanding: CompetitionQueryUnderstanding(
        directions: const ['算法'], categories: const [],
        timingPreferences: const [], teamPreferences: const [], uncertainties: const [],
      ),
      recommendations: [RecommendedCompetition(
        id: 'c0', name: '原地竞赛卡', category: '计算机类', level: '国家级',
        tags: const [], teamSize: '', signupTime: '', contestTime: '',
        format: '', organizer: '', officialUrl: null, reason: '', preparationTips: const [], limitations: const [], matchScore: 0.7,
      )],
      followUpQuestions: const [],
    ));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('竞赛 tab 提交后原地展示推荐卡，不跳路由', (t) async {
    final container = ProviderContainer(overrides: [
      competitionRecommendationRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomePage()),
    ));
    // 切到竞赛 tab
    await t.tap(find.text('竞赛'));
    await t.pumpAndSettle();
    // 输入并提交
    await t.enterText(find.byType(TextField).first, '我想参加算法竞赛');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('原地竞赛卡'), findsOneWidget);
    expect(find.text('调整条件'), findsOneWidget);
  });
}
```

注：tab 切换控件与输入框定位以实际 `home_page.dart` 为准，实施时调整 finder。`HomePage` 构造与 `_HomeTab.竞赛` 文案以源码为准（`home_page.dart:40-47`）。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/home_page_competition_inplace_test.dart`
Expected: FAIL — 提交后跳转，无"原地竞赛卡"。

- [ ] **Step 3: Write minimal implementation**

修改 `home_page.dart`：

1. 竞赛 tab `_submit` 分支：删除 `context.push('/competition-recommendation')`，改为
   ```dart
   setState(() { _submitting = true; _inConversation = true; });
   WidgetsBinding.instance.addPostFrameCallback((_) async {
     if (!mounted) return;
     await ref.read(competitionHomeProvider.notifier).submit(prompt);
   });
   _controller.clear();
   setState(() => _submitting = false);
   ```
2. `_buildConversationContent`（或竞赛 tab 的内容构建）在 `_currentTab == competition` 时渲染 `CompetitionHomeResultView(state: ref.watch(competitionHomeProvider), onAdjust: _adjustCompetition, onRetry: (p) => ref.read(competitionHomeProvider.notifier).submit(p))`。
3. 新增 `_adjustCompetition`：
   ```dart
   void _adjustCompetition() {
     ref.read(competitionHomeProvider.notifier).reset();
     setState(() { _inConversation = false; });
   }
   ```
4. 保留 `/competition-recommendation` 路由不变（深链/历史入口，复用新组件——见 Plan B/A11）。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/home_page_competition_inplace_test.dart`
Expected: PASS。

- [ ] **Step 5: Run full home + competition suites**

Run: `flutter test test/features/home/ test/features/competition_recommendation/`
Expected: PASS（修复任何因移除跳转导致的旧 `competition_recommendation_page` 测试预期——旧页面仍存在但首页不再跳转，旧页面测试应仍独立通过）。

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/pages/home_page.dart test/features/home/home_page_competition_inplace_test.dart
git commit -m "feat(home): 竞赛 tab 改为首页原地响应"
```

---

## Task A11: 验证与收尾

**Files:** 无新文件

- [ ] **Step 1: Run analyze**

Run: `flutter analyze`
Expected: 无 error（warning 可接受但尽量清零）。

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: PASS（记录总数，对比基线 131 文件）。

- [ ] **Step 3: 大字体/375px/深色不溢出**

手动或 widget test：`t.binding.window.physicalSizeTestValue = Size(375 * dpr, 800 * dpr)`，`textScaleFactor: 1.5`，`ThemeData(brightness: Brightness.dark)`，pump `CompetitionHomeResultView` result 态，断言无 overflow exception。

- [ ] **Step 4: Commit & update memory**

```bash
git add -A
git commit -m "test(competition): 首页原地响应无障碍/大字体验证"
```

更新记忆 `schonavi-roadmap-status.md`：Plan A 完成。

---

## Plan A 自检

- spec §4.1 展示模型 → A2/A3/A4 ✓
- spec §5.1 状态机 + 竞态 → A8 ✓
- spec §5.2 仓库保持非流式 → A8 未改仓库接口 ✓
- spec §5.3 泛型 carousel + 展示卡 + 需求卡 Bento 化 → A5/A6/A7 ✓
- spec §5.4 首页不跳转 → A10 ✓
- 匹配度派生 → A1 ✓
- UI 一致性/44px/语义/大字体 → A5/A6/A11 ✓
- 范围控制：未做竞赛多轮、未做 SSE（A8 状态机即异步，预留 SSE 在 data 层）✓
