# Plan B: 竞赛详情页 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新建 `/competition/:id` 竞赛详情页，按目录权威赛制展示完整字段（报名时间/比赛时间/团队规模/形式/主办方/注意事项/官网），AI 返回的 limitations/preparationTips 作为"补充提示"独立区块，提供官网入口；备赛入口（"开始备赛/继续备赛"）由 Plan C 接入，本计划预留按钮位。

**Architecture:** 详情页字段来源 = 目录优先（按 `id` 查 `competitionCatalog` 权威赛制）+ 推荐结果 AI 补充。`RecommendedCompetition` 已含全部字段，但为支持从历史/深链进入（无推荐上下文），需支持"仅 id → 从目录查权威赛制"路径。新建 `CompetitionDetailPage` + 路由 + 目录查询服务。复用 `BentoTile`/`_KVRow` 视觉语言。

**Tech Stack:** Flutter, Riverpod, go_router, 现有冷调系统。

**关联 spec:** §2(D3/D13)、§6。

**依赖:** Plan A 完成（横滑卡点击进入详情用 `context.push('/competition/:id')`）。Plan C 在详情页接"开始备赛"按钮。

## Global Constraints

- 沿用 slate/indigo/cyan，44px 触控，语义标签，大字体不溢出。
- 目录事实（signupTime/contestTime/teamSize/format/organizer/officialUrl）优先；AI 的 limitations/preparationTips 仅作"补充提示"区块，不覆盖目录事实。
- TDD，频繁提交。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/domain/repositories/competition_catalog_repository.dart` | 目录查询接口 `findById(String id) -> RecommendedCompetition?`（新建） |
| `lib/data/fixtures/competition_catalog_repository_impl.dart` | 基于 `competitionCatalog` 的实现 + provider（新建） |
| `lib/features/competition_recommendation/pages/competition_detail_page.dart` | 详情页（新建） |
| `lib/features/competition_recommendation/widgets/competition_fact_block.dart` | 目录事实键值区块（BentoTile + _KVRow）（新建） |
| `lib/features/competition_recommendation/widgets/competition_ai_tips_block.dart` | AI 补充提示区块（新建） |
| `lib/core/router/app_router.dart` | 注册 `/competition/:id`（修改） |
| `lib/features/competition_recommendation/widgets/competition_home_result_view.dart` | 横滑卡 onTap 改为 push 详情（修改，Plan A 已建） |

---

## Task B1: 目录查询接口与实现

**Files:**
- Create: `lib/domain/repositories/competition_catalog_repository.dart`
- Create: `lib/data/fixtures/competition_catalog_repository_impl.dart`
- Modify: `lib/core/di/providers.dart`（加 provider）
- Test: `test/data/fixtures/competition_catalog_repository_impl_test.dart`

**Interfaces:**
- Produces: `CompetitionCatalogRepository.findById(String id) -> RecommendedCompetition?`；provider `competitionCatalogRepositoryProvider`。

- [ ] **Step 1: Write the failing test**

```dart
// test/data/fixtures/competition_catalog_repository_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/fixtures/competition_catalog_repository_impl.dart';

void main() {
  test('findById 命中', () {
    final repo = StaticCompetitionCatalogRepository();
    final c = repo.findById('comp_icpc');
    expect(c, isNotNull);
    expect(c!.name, 'ACM-ICPC 国际大学生程序设计竞赛');
    expect(c.category, '计算机类');
  });

  test('findById 未命中返回 null', () {
    final repo = StaticCompetitionCatalogRepository();
    expect(repo.findById('nope'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/fixtures/competition_catalog_repository_impl_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/repositories/competition_catalog_repository.dart
import '../entities/recommended_competition.dart';

abstract interface class CompetitionCatalogRepository {
  RecommendedCompetition? findById(String id);
}
```

```dart
// lib/data/fixtures/competition_catalog_repository_impl.dart
import '../../domain/repositories/competition_catalog_repository.dart';
import 'competition_catalog.dart';

class StaticCompetitionCatalogRepository
    implements CompetitionCatalogRepository {
  const StaticCompetitionCatalogRepository();

  @override
  RecommendedCompetition? findById(String id) {
    for (final c in competitionCatalog) {
      if (c.id == id) return c;
    }
    return null;
  }
}
```

在 `lib/core/di/providers.dart` 加：

```dart
final competitionCatalogRepositoryProvider = Provider<CompetitionCatalogRepository>(
  (_) => const StaticCompetitionCatalogRepository(),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/fixtures/competition_catalog_repository_impl_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/competition_catalog_repository.dart lib/data/fixtures/competition_catalog_repository_impl.dart lib/core/di/providers.dart test/data/fixtures/competition_catalog_repository_impl_test.dart
git commit -m "feat(competition): 目录查询仓储"
```

---

## Task B2: 目录事实区块 CompetitionFactBlock

**Files:**
- Create: `lib/features/competition_recommendation/widgets/competition_fact_block.dart`
- Test: `test/features/competition_recommendation/widgets/competition_fact_block_test.dart`

**Interfaces:**
- Consumes: `RecommendedCompetition`、`BentoTile`、`AppColors`。
- Produces: `CompetitionFactBlock({required RecommendedCompetition competition})`，渲染目录事实键值行：报名时间、比赛时间、团队规模、形式、主办方。空值显示"暂无信息"（inkFaint）。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/competition_recommendation/widgets/competition_fact_block_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/features/competition_recommendation/widgets/competition_fact_block.dart';

RecommendedCompetition _c() => const RecommendedCompetition(
      id: 'c', name: 'C', category: '计算机类', level: '国家级',
      tags: [], teamSize: '3 人团队', signupTime: '约每年 4 月',
      contestTime: '9-12 月', format: '5 小时编程', organizer: 'ACM',
      officialUrl: 'https://x', reason: '', preparationTips: [], limitations: [], matchScore: 0,
    );

void main() {
  testWidgets('渲染目录事实键值', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: CompetitionFactBlock(competition: _c()))));
    expect(find.text('报名时间'), findsOneWidget);
    expect(find.text('约每年 4 月'), findsOneWidget);
    expect(find.text('比赛时间'), findsOneWidget);
    expect(find.text('团队规模'), findsOneWidget);
    expect(find.text('3 人团队'), findsOneWidget);
    expect(find.text('形式'), findsOneWidget);
    expect(find.text('主办方'), findsOneWidget);
    expect(find.text('ACM'), findsOneWidget);
  });

  testWidgets('空值显示暂无信息', (t) async {
    final c = _c().copyWith(signupTime: '', teamSize: '');
    await t.pumpWidget(MaterialApp(home: Scaffold(body: CompetitionFactBlock(competition: c))));
    expect(find.text('暂无信息'), findsNWidgets(2));
  });
}
```

注：`RecommendedCompetition` 需有 `copyWith`。若不存在，本任务先在实体上加 `copyWith`（见 Step 3）。先读 `recommended_competition.dart` 确认。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/competition_recommendation/widgets/competition_fact_block_test.dart`
Expected: FAIL — 文件/copyWith 不存在。

- [ ] **Step 3: Write minimal implementation**

若 `RecommendedCompetition` 无 `copyWith`，先加：

```dart
// 追加到 lib/domain/entities/recommended_competition.dart
  RecommendedCompetition copyWith({
    String? id, String? name, String? category, String? level,
    List<String>? tags, String? teamSize, String? signupTime,
    String? contestTime, String? format, String? organizer,
    String? officialUrl, String? reason, List<String>? preparationTips,
    List<String>? limitations, double? matchScore,
  }) => RecommendedCompetition(
    id: id ?? this.id, name: name ?? this.name, category: category ?? this.category,
    level: level ?? this.level, tags: tags ?? this.tags, teamSize: teamSize ?? this.teamSize,
    signupTime: signupTime ?? this.signupTime, contestTime: contestTime ?? this.contestTime,
    format: format ?? this.format, organizer: organizer ?? this.organizer,
    officialUrl: officialUrl ?? this.officialUrl, reason: reason ?? this.reason,
    preparationTips: preparationTips ?? this.preparationTips,
    limitations: limitations ?? this.limitations, matchScore: matchScore ?? this.matchScore,
  );
```

```dart
// lib/features/competition_recommendation/widgets/competition_fact_block.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/recommended_competition.dart';
import '../../../shared/widgets/bento_tile.dart';

class CompetitionFactBlock extends StatelessWidget {
  const CompetitionFactBlock({super.key, required this.competition});
  final RecommendedCompetition competition;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    return BentoTile(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('赛制信息', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _KVRow(label: '报名时间', value: c.signupTime),
          _KVRow(label: '比赛时间', value: c.contestTime),
          _KVRow(label: '团队规模', value: c.teamSize),
          _KVRow(label: '形式', value: c.format),
          _KVRow(label: '主办方', value: c.organizer),
        ],
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  const _KVRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.ideographic,
        children: [
          SizedBox(width: 64, child: Text(label, style: textTheme.labelSmall?.copyWith(color: AppColors.inkSoft))),
          const SizedBox(width: 8),
          Expanded(child: Text(isEmpty ? '暂无信息' : value,
              style: textTheme.bodySmall?.copyWith(color: isEmpty ? AppColors.inkFaint : null))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/competition_recommendation/widgets/competition_fact_block_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/recommended_competition.dart lib/features/competition_recommendation/widgets/competition_fact_block.dart test/features/competition_recommendation/widgets/competition_fact_block_test.dart
git commit -m "feat(competition): 目录事实区块 + copyWith"
```

---

## Task B3: AI 补充提示区块 CompetitionAiTipsBlock

**Files:**
- Create: `lib/features/competition_recommendation/widgets/competition_ai_tips_block.dart`
- Test: `test/features/competition_recommendation/widgets/competition_ai_tips_block_test.dart`

**Interfaces:**
- Consumes: `RecommendedCompetition`（limitations + preparationTips）。
- Produces: `CompetitionAiTipsBlock({required RecommendedCompetition competition})`。两个列表都为空时不渲染（返回 SizedBox.shrink）。非空时 BentoTile + auto_awesome 头 + "AI 补充提示"标题 + 列表项。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/competition_recommendation/widgets/competition_ai_tips_block_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/features/competition_recommendation/widgets/competition_ai_tips_block.dart';

const _base = RecommendedCompetition(
  id: 'c', name: 'C', category: '计算机类', level: '国家级',
  tags: [], teamSize: '', signupTime: '', contestTime: '',
  format: '', organizer: '', officialUrl: null, reason: '',
  preparationTips: [], limitations: [], matchScore: 0,
);

void main() {
  testWidgets('两列表空时不渲染', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: CompetitionAiTipsBlock(competition: _base))));
    expect(find.text('AI 补充提示'), findsNothing);
  });

  testWidgets('有 limitations 和 tips 时渲染', (t) async {
    final c = _base.copyWith(
      preparationTips: const ['刷真题', '组队训练'],
      limitations: const ['以官网为准'],
    );
    await t.pumpWidget(MaterialApp(home: Scaffold(body: CompetitionAiTipsBlock(competition: c))));
    expect(find.text('AI 补充提示'), findsOneWidget);
    expect(find.text('· 刷真题'), findsOneWidget);
    expect(find.text('· 以官网为准'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/competition_recommendation/widgets/competition_ai_tips_block_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/competition_recommendation/widgets/competition_ai_tips_block.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/recommended_competition.dart';
import '../../../shared/widgets/bento_tile.dart';

class CompetitionAiTipsBlock extends StatelessWidget {
  const CompetitionAiTipsBlock({super.key, required this.competition});
  final RecommendedCompetition competition;

  @override
  Widget build(BuildContext context) {
    final tips = competition.preparationTips;
    final limits = competition.limitations;
    if (tips.isEmpty && limits.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return BentoTile(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.auto_awesome, size: 18, color: AppColors.indigo),
            SizedBox(width: 8),
          ]),
          Text('AI 补充提示', style: textTheme.titleMedium),
          // 注：标题 Row 内 Icon 后接 Text，实际写为 Row(children:[Icon, SizedBox, Text('AI 补充提示')])
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('备赛建议', style: textTheme.labelLarge),
            ...tips.map((x) => Text('· $x', style: textTheme.bodySmall)),
          ],
          if (limits.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('注意事项', style: textTheme.labelLarge),
            ...limits.map((x) => Text('· $x', style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft))),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/competition_recommendation/widgets/competition_ai_tips_block_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/competition_recommendation/widgets/competition_ai_tips_block.dart test/features/competition_recommendation/widgets/competition_ai_tips_block_test.dart
git commit -m "feat(competition): AI 补充提示区块"
```

---

## Task B4: 详情页 CompetitionDetailPage + 路由

**Files:**
- Create: `lib/features/competition_recommendation/pages/competition_detail_page.dart`
- Modify: `lib/core/router/app_router.dart`（加 `/competition/:id`）
- Test: `test/features/competition_recommendation/pages/competition_detail_page_test.dart`

**Interfaces:**
- Consumes: `competitionCatalogRepositoryProvider`、`linkLauncherProvider`、`CompetitionFactBlock`、`CompetitionAiTipsBlock`、`MatchLevelChip`（可选）。
- 构造：`CompetitionDetailPage({required String competitionId, RecommendedCompetition? recommended})`。`recommended` 可选：从横滑卡点击时传入（含 AI 字段 + matchScore）；从历史/深链进入时为 null，仅从目录查权威赛制（AI 区块隐藏，matchScore 缺省）。
- 字段合并策略：以目录查到的 `RecommendedCompetition` 为基底（权威事实），若传入 `recommended` 则用其 `limitations`/`preparationTips`/`matchScore`/`reason` 覆盖基底对应字段（事实字段仍以目录为准）。
- 页面：AppBar 标题=竞赛名；正文 ListView：名称头（含类别/级别 + matchScore chip）、`CompetitionFactBlock`、`CompetitionAiTipsBlock`、官网按钮（44px，cyan）、备赛按钮占位（本计划留 `SizedBox` 或 disabled 按钮，Plan C 接入）。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/competition_recommendation/pages/competition_detail_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/competition_recommendation/pages/competition_detail_page.dart';

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('从目录渲染详情，含赛制信息与官网', (t) async {
    await t.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CompetitionDetailPage(competitionId: 'comp_icpc')),
    ));
    await t.pumpAndSettle();
    expect(find.text('ACM-ICPC 国际大学生程序设计竞赛'), findsWidgets);
    expect(find.text('赛制信息'), findsOneWidget);
    expect(find.text('主办方'), findsOneWidget);
    expect(find.text('访问官网'), findsOneWidget);
  });

  testWidgets('未知 id 显示未找到', (t) async {
    await t.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CompetitionDetailPage(competitionId: 'nope')),
    ));
    await t.pumpAndSettle();
    expect(find.textContaining('未找到'), findsOneWidget);
  });

  testWidgets('传入 recommended 时显示 AI 补充提示', (t) async {
    // 从目录取基底，再 copyWith 注入 AI 字段模拟 recommended 传入
    await t.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CompetitionDetailPage(
        competitionId: 'comp_icpc',
        recommended: null, // 仅目录；AI 区块测试见 widget 测试 B3
      )),
    ));
    await t.pumpAndSettle();
    // 目录基底 limitations 为通用提示，preparationTips 非空 -> AI 区块应显示
    expect(find.text('AI 补充提示'), findsOneWidget);
  });
}
```

注：第三个测试依赖目录项 `comp_icpc` 的 `preparationTips`/`limitations` 非空（catalog 中确认非空），故 AI 区块应显示。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/competition_recommendation/pages/competition_detail_page_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/competition_recommendation/pages/competition_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/recommended_competition.dart';
import '../widgets/competition_ai_tips_block.dart';
import '../widgets/competition_fact_block.dart';

class CompetitionDetailPage extends ConsumerWidget {
  const CompetitionDetailPage({super.key, required this.competitionId, this.recommended});

  final String competitionId;
  final RecommendedCompetition? recommended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.read(competitionCatalogRepositoryProvider).findById(competitionId);
    if (base == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('未找到该竞赛', style: Theme.of(context).textTheme.bodyLarge)),
      );
    }
    // 目录事实优先；recommended 仅补 AI 字段与匹配度。
    final merged = recommended == null
        ? base
        : base.copyWith(
            limitations: recommended!.limitations,
            preparationTips: recommended!.preparationTips,
            matchScore: recommended!.matchScore,
            reason: recommended!.reason,
          );
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(merged.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BentoTile(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(merged.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${merged.category} / ${merged.level}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkSoft)),
                if (merged.reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(merged.reason, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          CompetitionFactBlock(competition: merged),
          const SizedBox(height: 12),
          CompetitionAiTipsBlock(competition: merged),
          const SizedBox(height: 16),
          if (merged.officialUrl != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.cyan, foregroundColor: Colors.white),
              onPressed: () => _openOfficial(context, ref, merged.officialUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('访问官网'),
            ),
          // 备赛按钮占位：Plan C 接入"开始备赛/继续备赛"。
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppColors.indigo),
            onPressed: null, // Plan C 接入
            icon: const Icon(Icons.flag_outlined),
            label: const Text('开始备赛'),
          ),
        ],
      ),
    );
  }

  Future<void> _openOfficial(BuildContext context, WidgetRef ref, String? url) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(linkLauncherProvider).open(url);
    switch (result) {
      case LaunchResult.success: return;
      case LaunchResult.noUrl: messenger.showSnackBar(const SnackBar(content: Text('暂无官网信息')));
      case LaunchResult.failed: messenger.showSnackBar(const SnackBar(content: Text('官网可能暂时无法打开')));
    }
  }
}
```

注意 `BentoTile` import 需补：`import '../../../shared/widgets/bento_tile.dart';`。

路由 `app_router.dart` 加：

```dart
GoRoute(
  path: '/competition/:id',
  pageBuilder: (_, state) => sharedAxisPage(
    state: state,
    child: CompetitionDetailPage(competitionId: state.pathParameters['id']!),
  ),
),
```
并加 import `import '../../features/competition_recommendation/pages/competition_detail_page.dart';`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/competition_recommendation/pages/competition_detail_page_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/competition_recommendation/pages/competition_detail_page.dart lib/core/router/app_router.dart test/features/competition_recommendation/pages/competition_detail_page_test.dart
git commit -m "feat(competition): 竞赛详情页 + /competition/:id 路由"
```

---

## Task B5: 横滑卡点击进入详情

**Files:**
- Modify: `lib/features/competition_recommendation/widgets/competition_home_result_view.dart`（Plan A 已建）
- Test: 扩展 `competition_home_result_view_test.dart`

**Interfaces:**
- 横滑卡 `onTap` 改为 `context.push('/competition/${c.id}')`，并把 `RecommendedCompetition` 通过 `extra` 或 query 传递给详情页（若需保留 AI 字段）。最简：仅 push id，详情页从目录取基底（AI 字段仍来自目录基底，因目录项本身含 preparationTips/limitations）。若想保留推荐上下文的 matchScore/reason，用 `extra: c`。

- [ ] **Step 1: Write the failing test**

在 `competition_home_result_view_test.dart` 增：

```dart
testWidgets('点击卡片触发 onOpenDetail', (t) async {
  var opened = '';
  // 注入 onOpenDetail 回调（视图需新增参数）
  await t.pumpWidget(_wrap(CompetitionHomeResultView(
    state: CompetitionHomeResult(_res(1)),
    onAdjust: () {},
    onRetry: (_) async {},
    onOpenDetail: (id) => opened = id,
  )));
  await t.tap(find.text('竞赛0'));
  await t.pump();
  expect(opened, 'c0');
});
```

注：`CompetitionHomeResultView` 需新增 `onOpenDetail` 参数（Plan A 建时可能未加；本任务补）。若 Plan A 已用 `context.push` 内联，则本任务改为回调注入便于测试。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/competition_recommendation/widgets/competition_home_result_view_test.dart`
Expected: FAIL — 无 onOpenDetail。

- [ ] **Step 3: Write minimal implementation**

`CompetitionHomeResultView` 加 `final void Function(String id)? onOpenDetail;`，横滑卡 `onTap: () => onOpenDetail?.call(c.id)`。首页 `home_page.dart` 传入 `onOpenDetail: (id) => context.push('/competition/$id')`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/competition_recommendation/widgets/competition_home_result_view_test.dart`
Expected: PASS。

- [ ] **Step 5: Run full competition suite**

Run: `flutter test test/features/competition_recommendation/`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/features/competition_recommendation/widgets/competition_home_result_view.dart lib/features/home/pages/home_page.dart test/features/competition_recommendation/widgets/competition_home_result_view_test.dart
git commit -m "feat(competition): 横滑卡点击进入详情页"
```

---

## Task B6: 验证与收尾

- [ ] **Step 1: Run analyze + full test**

Run: `flutter analyze && flutter test`
Expected: 无 error，全绿。

- [ ] **Step 2: 375px/大字/深色不溢出**

widget test：详情页 `comp_icpc`，375 宽 + textScale 1.5 + dark，断言无 overflow。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test(competition): 详情页无障碍验证"
```

---

## Plan B 自检

- spec §6 目录优先 + AI 补充 → B4 合并策略 ✓
- spec §6 官网入口 → B4 ✓
- spec §6 "开始备赛"在详情页 → B4 占位，Plan C 接入 ✓（本计划明确预留）
- spec §5.4 卡片主体点击进详情 → B5 ✓
- spec §6 保留 /competition-recommendation 深链入口 → 路由未删，A10 后首页不再跳转但深链仍可用 ✓
- 范围：未做备赛逻辑（留给 Plan C）✓
