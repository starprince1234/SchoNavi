# SchoNavi Phase 1 · 旗舰① 匹配雷达 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「匹配分析」升级为多维**契合度雷达图 + 逐维 AI 解读**，直观展示大模型结构化输出，且不破坏既有匹配功能与测试。

**Architecture:** 扩展 `MatchAnalysis` 增加 `dimensions`（5 固定轴，信息性契合度、非录取概率）；`Mock/Ai` 仓储填充该字段（AI 走 `jsonMode` 接地）；新增 `RadarChart`（绘制 + 可点轴标签）；重做匹配页 `_AnalysisView`，雷达 + 综合 `StatTile` 数字滚动 + 点轴弹 `showAppBottomSheet` 看解读，**保留**原有总体/匹配点/差距/建议三段与免责。

**Tech Stack:** Flutter（CustomPaint）· Riverpod 3 · 既有 `LlmClient`/`Result`。

**Spec:** `docs/superpowers/specs/2026-06-10-schonavi-bento-enhancement-design.md` §5.1。

**前置:** **Phase 0 已完成**（依赖 `core/haptics/haptics.dart`、`core/ui/app_bottom_sheet.dart`、`shared/widgets/stat_tile.dart`、`shared/widgets/section_header.dart` 与 Bento 主题）。

**关键护栏（不可破坏的既有测试断言）:**
- `MatchAnalysis` 新字段必须**可选**（`dimensions = const []`）——`match_analysis_test`/`match_provider_test`/`match_page_test` 都用旧 4 字段构造。
- AI 解析在 JSON **无 dimensions** 时仍 `Success`（`ai_match_analysis_repository_test` 的 `_validJson()` 不含 dimensions）。
- AI 接地用户消息仍含导师方向/学生已填字段、不含未填字段（grounding 测试）。
- 匹配页仍显示「仅供参考 / 总体匹配 / 匹配点 / 差距与短板 / 准备建议 / 重新生成」；dimensions 为空时**不渲染雷达**。

**约定提醒:** 包名 `scho_navi`；TDD；频繁提交；命令在仓库根执行。

---

## File Structure

- Modify `lib/domain/entities/match_analysis.dart` — 增 `MatchDimension` + `dimensions` 字段。
- Modify `lib/data/mock/mock_match_analysis_repository.dart` — 填 5 维。
- Modify `lib/data/ai/ai_match_analysis_repository.dart` — prompt 增 dimensions + 解析（clamp/兜底）。
- Create `lib/shared/widgets/radar_chart.dart` — 雷达组件（绘制 + 可点轴）。
- Modify `lib/features/match/pages/match_page.dart` — `_AnalysisView` 重做。
- Tests: `test/domain/entities/match_analysis_test.dart`、`test/data/mock/...`、`test/data/ai/...`、`test/shared/widgets/radar_chart_test.dart`、`test/features/match/match_page_test.dart`。

固定 5 轴（顺序固定，保证雷达可比）：`方向契合`、`方法匹配`、`地域`、`学历目标`、`产出活跃`。

---

## Task 1: 领域 — MatchDimension + dimensions 字段

**Files:**
- Modify: `lib/domain/entities/match_analysis.dart`
- Test: `test/domain/entities/match_analysis_test.dart`

- [ ] **Step 1: 追加失败测试**

在 `test/domain/entities/match_analysis_test.dart` 的 `main()` 内追加：

```dart
  test('MatchAnalysis 默认 dimensions 为空、可携带维度', () {
    const empty = MatchAnalysis(
      professorId: 'p',
      summary: 's',
      strengths: [],
      gaps: [],
      suggestions: [],
    );
    expect(empty.dimensions, isEmpty);

    const dim = MatchDimension(label: '方向契合', score: 90, comment: '高度重合');
    const withDims = MatchAnalysis(
      professorId: 'p',
      summary: 's',
      strengths: [],
      gaps: [],
      suggestions: [],
      dimensions: [dim],
    );
    expect(withDims.dimensions.single.label, '方向契合');
    expect(withDims.dimensions.single.score, 90);
    expect(withDims.dimensions.single.comment, '高度重合');
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/domain/entities/match_analysis_test.dart`
Expected: FAIL（`MatchDimension` 未定义、`dimensions` 参数不存在）。

- [ ] **Step 3: 扩展实体**

整体替换 `lib/domain/entities/match_analysis.dart`：

```dart
/// 单个契合维度（信息性，非录取概率）。
class MatchDimension {
  const MatchDimension({
    required this.label,
    required this.score,
    required this.comment,
  });

  final String label; // 固定 5 轴之一
  final int score; // 0–100
  final String comment; // 该维度的接地解读
}

/// 导师-学生背景匹配分析（信息性，非录取概率预测）。
class MatchAnalysis {
  const MatchAnalysis({
    required this.professorId,
    required this.summary,
    required this.strengths,
    required this.gaps,
    required this.suggestions,
    this.dimensions = const [],
  });

  final String professorId;
  final String summary;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> suggestions;
  final List<MatchDimension> dimensions;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/domain/entities/match_analysis_test.dart`
Expected: PASS（含原「保存四部分」测试）。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/match_analysis.dart test/domain/entities/match_analysis_test.dart
git commit -m "feat(match): add MatchDimension and optional dimensions to MatchAnalysis"
```

---

## Task 2: Mock 仓储填充 5 维

**Files:**
- Modify: `lib/data/mock/mock_match_analysis_repository.dart`
- Test: `test/data/mock/mock_match_analysis_repository_test.dart`

- [ ] **Step 1: 追加失败测试**

在 `test/data/mock/mock_match_analysis_repository_test.dart` 的 `main()` 内追加：

```dart
  test('生成固定 5 维，分数 0–100', () async {
    final result = await MockMatchAnalysisRepository().analyze(
      professor: _professor,
      profile: const UserProfile(name: '李四', researchInterests: ['医学影像']),
    );
    final dims = (result as Success<MatchAnalysis>).data.dimensions;

    expect(dims.map((d) => d.label).toList(),
        ['方向契合', '方法匹配', '地域', '学历目标', '产出活跃']);
    for (final d in dims) {
      expect(d.score, inInclusiveRange(0, 100));
      expect(d.comment, isNotEmpty);
    }
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/data/mock/mock_match_analysis_repository_test.dart`
Expected: FAIL（`dimensions` 为空）。

- [ ] **Step 3: 在 mock 中构造 5 维**

在 `lib/data/mock/mock_match_analysis_repository.dart` 的 `analyze` 内，`return Success(...)` 之前插入维度构造，并把 `dimensions` 传入 `MatchAnalysis`：

```dart
    final hasOverlap = overlap.isNotEmpty;
    final dimensions = <MatchDimension>[
      MatchDimension(
        label: '方向契合',
        score: hasOverlap ? 88 : 62,
        comment: hasOverlap
            ? '你的兴趣与 ${overlap.join('、')} 直接重合。'
            : '与 $fields 有一定关联，建议进一步对照。',
      ),
      MatchDimension(
        label: '方法匹配',
        score: profile.major != null ? 74 : 60,
        comment: profile.major != null
            ? '你的 ${profile.major} 背景可支撑相关方法。'
            : '方法匹配度需结合你的具体技能判断。',
      ),
      const MatchDimension(
        label: '地域',
        score: 70,
        comment: '地域偏好需结合你的意向城市确认。',
      ),
      MatchDimension(
        label: '学历目标',
        score: profile.degreeStage != null ? 72 : 58,
        comment: profile.degreeStage != null
            ? '你的目标阶段（${profile.degreeStage}）可与导师招生匹配。'
            : '建议补充目标阶段（硕/博）以评估。',
      ),
      const MatchDimension(
        label: '产出活跃',
        score: 68,
        comment: '导师近年产出与名额请以官网/回复为准。',
      ),
    ];
```

并把返回改为：

```dart
    return Success(
      MatchAnalysis(
        professorId: professor.id,
        summary: '这是一份基于已提供信息的 $fields 匹配分析，仅供准备沟通时参考。',
        strengths: strengths,
        gaps: gaps,
        suggestions: suggestions,
        dimensions: dimensions,
      ),
    );
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/data/mock/mock_match_analysis_repository_test.dart`
Expected: PASS（含原两条）。

- [ ] **Step 5: Commit**

```bash
git add lib/data/mock/mock_match_analysis_repository.dart test/data/mock/mock_match_analysis_repository_test.dart
git commit -m "feat(match): mock repository emits five fit dimensions"
```

---

## Task 3: AI 仓储 — prompt 增维度 + 解析（clamp/兜底）

**Files:**
- Modify: `lib/data/ai/ai_match_analysis_repository.dart`
- Test: `test/data/ai/ai_match_analysis_repository_test.dart`

- [ ] **Step 1: 追加失败测试（含维度的 JSON 被解析、分数 clamp、缺维度退化为空）**

在 `test/data/ai/ai_match_analysis_repository_test.dart` 的 `main()` 内追加：

```dart
  test('解析 dimensions：补齐为固定 5 轴并 clamp 分数', () async {
    final json = jsonEncode({
      'summary': '较契合。',
      'strengths': ['x'],
      'gaps': ['y'],
      'suggestions': ['z'],
      'dimensions': [
        {'label': '方向契合', 'score': 120, 'comment': '重合度高'},
        {'label': '地域', 'score': -5, 'comment': '需确认'},
      ],
    });
    final repo = AiMatchAnalysisRepository(_FakeLlm(Success(json)));

    final analysis = (await repo.analyze(
      professor: _professor,
      profile: const UserProfile(),
    ) as Success<MatchAnalysis>).data;

    final byLabel = {for (final d in analysis.dimensions) d.label: d};
    expect(analysis.dimensions, hasLength(5)); // 补齐固定 5 轴
    expect(byLabel['方向契合']!.score, 100); // clamp 上界
    expect(byLabel['地域']!.score, 0); // clamp 下界
    expect(byLabel['方法匹配']!.comment, '信息不足'); // 缺轴补齐
  });

  test('无 dimensions 字段仍成功（退化为空）', () async {
    final repo = AiMatchAnalysisRepository(_FakeLlm(Success(_validJson())));
    final analysis = (await repo.analyze(
      professor: _professor,
      profile: const UserProfile(),
    ) as Success<MatchAnalysis>).data;
    expect(analysis.dimensions, isEmpty);
    expect(analysis.summary, isNotEmpty);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/data/ai/ai_match_analysis_repository_test.dart`
Expected: FAIL（首个新测试：dimensions 为空，长度断言不符）。

- [ ] **Step 3: 解析维度 + 扩展系统提示词**

在 `lib/data/ai/ai_match_analysis_repository.dart`：

(a) `_parseAnalysis` 的 `Success(MatchAnalysis(...))` 增 `dimensions: _dimensions(decoded['dimensions']),`：

```dart
      return Success(
        MatchAnalysis(
          professorId: professorId,
          summary: summary,
          strengths: _strings(decoded['strengths']),
          gaps: _strings(decoded['gaps']),
          suggestions: _strings(decoded['suggestions']),
          dimensions: _dimensions(decoded['dimensions']),
        ),
      );
```

(b) 在 `_strings` 方法下方新增固定 5 轴常量与解析助手（补齐缺轴、clamp 取整）：

```dart
  static const List<String> _axes = [
    '方向契合', '方法匹配', '地域', '学历目标', '产出活跃',
  ];

  List<MatchDimension> _dimensions(Object? value) {
    final list = value as List? ?? const [];
    final parsed = <String, MatchDimension>{};
    for (final item in list) {
      if (item is! Map) continue;
      final label = (item['label'] as String?)?.trim();
      if (label == null || label.isEmpty) continue;
      final raw = item['score'];
      final n = raw is num ? raw.round() : int.tryParse('$raw') ?? 0;
      final score = n.clamp(0, 100).toInt();
      final comment = (item['comment'] as String?)?.trim() ?? '';
      parsed[label] = MatchDimension(label: label, score: score, comment: comment);
    }
    if (parsed.isEmpty) return const []; // 旧/无 dimensions → 退化为空，雷达不渲染
    return [
      for (final axis in _axes)
        parsed[axis] ??
            MatchDimension(label: axis, score: 0, comment: '信息不足'),
    ];
  }
```

(c) 整体替换 `_systemPrompt` 常量（在原四段基础上增 dimensions 规则；保持「不编造/非录取概率」）：

```dart
  static const String _systemPrompt = '''
你是帮学生做"导师-背景匹配分析"的助手。根据【导师】与【学生背景】输出一个 JSON 对象，不要 Markdown 或多余文字：
{"summary":"...","strengths":["..."],"gaps":["..."],"suggestions":["..."],"dimensions":[{"label":"方向契合","score":0,"comment":"..."},{"label":"方法匹配","score":0,"comment":"..."},{"label":"地域","score":0,"comment":"..."},{"label":"学历目标","score":0,"comment":"..."},{"label":"产出活跃","score":0,"comment":"..."}]}
规则：
1. strengths：学生与该导师方向或要求的契合点，只基于已提供信息。
2. gaps：可能的短板；信息缺失则写"建议补充X"，不臆测学生未提供的经历。
3. suggestions：具体可执行的准备，如补哪类基础、读哪方向论文、准备什么材料。
4. summary：客观概述匹配情况，严禁给出录取概率或"一定能/不能"的结论。
5. dimensions：必须且仅含上面 5 个 label（顺序不限），score 为 0-100 的"信息性契合度"（非录取概率），comment 为该维度一句话接地解读；信息不足的维度给较低分并在 comment 说明需补充什么。
6. 不得编造导师或学生未提供的任何事实。
''';
```

- [ ] **Step 4: 运行确认通过（含原 5 条）**

Run: `flutter test test/data/ai/ai_match_analysis_repository_test.dart`
Expected: PASS（原 grounding/坏 JSON/缺 summary/失败透传 全绿；`_validJson` 无 dimensions → 空）。

- [ ] **Step 5: Commit**

```bash
git add lib/data/ai/ai_match_analysis_repository.dart test/data/ai/ai_match_analysis_repository_test.dart
git commit -m "feat(match): AI repository parses grounded fit dimensions with clamping"
```

---

## Task 4: RadarChart 组件（绘制 + 可点轴）

**Files:**
- Create: `lib/shared/widgets/radar_chart.dart`
- Test: `test/shared/widgets/radar_chart_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/shared/widgets/radar_chart_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/shared/widgets/radar_chart.dart';

const _dims = [
  MatchDimension(label: '方向契合', score: 90, comment: 'a'),
  MatchDimension(label: '方法匹配', score: 78, comment: 'b'),
  MatchDimension(label: '地域', score: 95, comment: 'c'),
  MatchDimension(label: '学历目标', score: 70, comment: 'd'),
  MatchDimension(label: '产出活跃', score: 82, comment: 'e'),
];

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('渲染全部轴标签', (tester) async {
    await tester.pumpWidget(_wrap(const RadarChart(dimensions: _dims)));
    await tester.pumpAndSettle();
    expect(find.text('方向契合'), findsOneWidget);
    expect(find.text('产出活跃'), findsOneWidget);
  });

  testWidgets('点轴标签触发 onAxisTap(index)', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      _wrap(RadarChart(dimensions: _dims, onAxisTap: (i) => tapped = i)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('地域'));
    expect(tapped, 2);
  });

  testWidgets('空维度渲染为空占位', (tester) async {
    await tester.pumpWidget(_wrap(const RadarChart(dimensions: [])));
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets); // 不抛错即可
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/shared/widgets/radar_chart_test.dart`
Expected: FAIL（`radar_chart.dart` 不存在）。

- [ ] **Step 3: 实现 RadarChart**

创建 `lib/shared/widgets/radar_chart.dart`：

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/match_analysis.dart';

/// 契合度雷达：CustomPaint 网格 + 数据多边形（描边生长动画），轴标签可点。
class RadarChart extends StatefulWidget {
  const RadarChart({
    super.key,
    required this.dimensions,
    this.onAxisTap,
    this.size = 260,
  });

  final List<MatchDimension> dimensions;
  final void Function(int index)? onAxisTap;
  final double size;

  @override
  State<RadarChart> createState() => _RadarChartState();
}

class _RadarChartState extends State<RadarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = widget.dimensions;
    if (dims.isEmpty) {
      return const SizedBox(
        width: 1,
        height: 1,
        child: CustomPaint(),
      );
    }
    final n = dims.length;
    final size = widget.size;
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 34; // 留出标签空间

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RadarPainter(
                  dimensions: dims,
                  progress: Curves.easeOutCubic.transform(_c.value),
                  grid: AppColors.line,
                  fill: AppColors.coral.withValues(alpha: 0.20),
                  stroke: AppColors.coral,
                ),
              ),
              for (var i = 0; i < n; i++)
                _axisLabel(context, i, n, center, radius, dims[i]),
            ],
          );
        },
      ),
    );
  }

  Widget _axisLabel(
    BuildContext context,
    int i,
    int n,
    Offset center,
    double radius,
    MatchDimension dim,
  ) {
    final angle = -math.pi / 2 + 2 * math.pi * i / n;
    final lx = center.dx + (radius + 18) * math.cos(angle);
    final ly = center.dy + (radius + 18) * math.sin(angle);
    final theme = Theme.of(context);
    return Positioned(
      left: lx - 34,
      top: ly - 16,
      width: 68,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onAxisTap == null
            ? null
            : () {
                Haptics.selection();
                widget.onAxisTap!(i);
              },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dim.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
            Text(
              '${dim.score}',
              style: theme.textTheme.labelLarge?.copyWith(color: AppColors.coral),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.dimensions,
    required this.progress,
    required this.grid,
    required this.fill,
    required this.stroke,
  });

  final List<MatchDimension> dimensions;
  final double progress;
  final Color grid;
  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final n = dimensions.length;
    if (n < 3) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 34;

    Offset vertex(double r, int i) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    }

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;

    // 同心网格（3 圈）
    for (final ring in [1 / 3, 2 / 3, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = vertex(radius * ring, i);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    // 轴线
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, vertex(radius, i), gridPaint);
    }

    // 数据多边形（按 progress 生长）
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final r = radius * (dimensions[i].score / 100) * progress;
      final p = vertex(r, i);
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()..color = fill);
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = stroke,
    );
    // 顶点圆点
    for (var i = 0; i < n; i++) {
      final r = radius * (dimensions[i].score / 100) * progress;
      canvas.drawCircle(vertex(r, i), 3, Paint()..color = stroke);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress || old.dimensions != dimensions;
}
```

> 注：`Color.withValues(alpha:)` 为新版 Flutter API（替代 `withOpacity`）；若分析器报不存在，改用 `stroke.withOpacity(0.20)`。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/shared/widgets/radar_chart_test.dart`
Expected: PASS（3 条）。

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/radar_chart.dart test/shared/widgets/radar_chart_test.dart
git commit -m "feat(widgets): animated RadarChart with tappable axes"
```

---

## Task 5: 匹配页重做（雷达 + 综合数字 + 点轴解读，保留三段）

**Files:**
- Modify: `lib/features/match/pages/match_page.dart`
- Test: `test/features/match/match_page_test.dart`

- [ ] **Step 1: 追加失败测试（有维度时显示雷达 + 点轴看解读）**

在 `test/features/match/match_page_test.dart` 的 `main()` 内追加（复用文件顶部的 `_wrap`/`_FakeProfileRepo`/`_FakeMatchRepo`）：

```dart
  testWidgets('有维度时显示雷达与综合分，点轴看解读', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final matchRepo = _FakeMatchRepo(
      const MatchAnalysis(
        professorId: 'p_001',
        summary: '方向较契合。',
        strengths: ['研究方向一致'],
        gaps: ['缺少论文'],
        suggestions: ['补读综述'],
        dimensions: [
          MatchDimension(label: '方向契合', score: 90, comment: '高度重合的方向'),
          MatchDimension(label: '方法匹配', score: 70, comment: 'm'),
          MatchDimension(label: '地域', score: 80, comment: 'r'),
          MatchDimension(label: '学历目标', score: 60, comment: 'd'),
          MatchDimension(label: '产出活跃', score: 50, comment: 'o'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(profileRepo, matchRepo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始匹配分析'));
    await tester.pumpAndSettle();

    expect(find.text('综合契合度（信息性）'), findsOneWidget); // 雷达区已渲染
    await tester.tap(find.text('方向契合'));
    await tester.pumpAndSettle();
    expect(find.text('高度重合的方向'), findsOneWidget); // 抽屉内解读
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/features/match/match_page_test.dart`
Expected: FAIL（找不到「70」/「高度重合的方向」）。

- [ ] **Step 3: 重做 `_AnalysisView`**

在 `lib/features/match/pages/match_page.dart` 顶部补充 import：

```dart
import '../../../core/ui/app_bottom_sheet.dart';
import '../../../shared/widgets/radar_chart.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_tile.dart';
```

整体替换 `class _AnalysisView ...`（保留 `_Section` 不变）：

```dart
class _AnalysisView extends StatelessWidget {
  const _AnalysisView({required this.analysis, required this.onRegenerate});

  final MatchAnalysis analysis;
  final VoidCallback onRegenerate;

  int? get _overall {
    final dims = analysis.dimensions;
    if (dims.isEmpty) return null;
    final sum = dims.fold<int>(0, (a, d) => a + d.score);
    return (sum / dims.length).round();
  }

  void _showDimension(BuildContext context, MatchDimension dim) {
    showAppBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dim.label, style: Theme.of(context).textTheme.titleLarge),
                Text('${dim.score}',
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(dim.comment, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overall = _overall;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.surfaceContainer,
          margin: EdgeInsets.zero,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('本分析仅供参考，不预测录取概率，请结合实际情况判断。'),
          ),
        ),
        if (analysis.dimensions.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (overall != null)
            Center(child: StatTile(value: overall, label: '综合契合度（信息性）')),
          const SizedBox(height: 8),
          Center(
            child: RadarChart(
              dimensions: analysis.dimensions,
              onAxisTap: (i) =>
                  _showDimension(context, analysis.dimensions[i]),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('点任一维度查看 AI 解读',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
        const SizedBox(height: 18),
        const SectionHeader('总体匹配'),
        const SizedBox(height: 6),
        Text(analysis.summary),
        const SizedBox(height: 18),
        _Section(
          icon: Icons.check_circle_outline,
          title: '匹配点',
          items: analysis.strengths,
        ),
        _Section(
          icon: Icons.report_problem_outlined,
          title: '差距与短板',
          items: analysis.gaps,
        ),
        _Section(
          icon: Icons.lightbulb_outline,
          title: '准备建议',
          items: analysis.suggestions,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onRegenerate,
            icon: const Icon(Icons.refresh),
            label: const Text('重新生成'),
          ),
        ),
      ],
    );
  }
}
```

> 说明：原「总体匹配」用 `Text(..., titleMedium)`，这里替换为 `SectionHeader('总体匹配')`——`match_page_test` 用 `find.text('总体匹配')` 仍匹配（`SectionHeader` 内是同名 `Text`）。其余三段标题经 `_Section` 渲染，文本不变。

- [ ] **Step 4: 运行确认通过（含原两条 widget 测试）**

Run: `flutter test test/features/match/match_page_test.dart`
Expected: PASS（原「三段 + 免责」「重新生成再次调用」+ 新「雷达/点轴」均绿；旧两条 analysis 无 dimensions → 不渲染雷达，断言不受影响）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/match/pages/match_page.dart test/features/match/match_page_test.dart
git commit -m "feat(match): radar + overall score + per-axis AI explanation on match page"
```

---

## Task 6: 收口校验 + 手动冒烟

**Files:** 无新增（验收任务）。

- [ ] **Step 1: 全量静态检查**

Run: `flutter analyze`
Expected: `No issues found!`（如报 `withValues` 不存在，按 Task 4 注释改 `withOpacity` 后重跑）。

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: 全部通过（匹配相关 + 既有回归全绿）。

- [ ] **Step 3: 手动冒烟**

Run: `flutter run`（mock 模式即可，mock 已产出 5 维）。
人工确认：
- 导师详情 →「匹配分析」→「开始匹配分析」→ 出现**综合契合度大数字滚动 + 雷达描边生长**。
- 点任一维度 → 底部抽屉显示该维 label/score/comment，可下滑关闭。
- 三段（匹配点/差距/建议）、免责、重新生成 均在。
- （可选）AI 模式：`flutter run --dart-define=LLM_API_KEY=sk-xxx`，真实生成 5 维。

- [ ] **Step 4: 收口提交（若有零碎修整）**

```bash
git add -A
git commit -m "chore: Phase 1 match radar smoke fixes"
```

> Phase 1 完成后，旗舰①「匹配雷达」上线（mock 可离线演示）。后续按 spec §9 进入 Phase 2（完成度收尾）与 Phase 3（旗舰②申请军师，依赖本页行动区接入）。
