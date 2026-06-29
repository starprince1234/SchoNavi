// test/data/local/local_preparation_template_provider_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/local/local_preparation_template_provider.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

class _StubBundle extends CachingAssetBundle {
  final Map<String, String> assets;
  _StubBundle(this.assets);
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final v = assets[key];
    if (v == null) throw Exception('missing $key');
    return v;
  }

  @override
  Future<ByteData> load(String key) async => throw Exception('binary load not supported in stub');
}

void main() {
  test('加载计算机类叠加任务', () async {
    final bundle = _StubBundle({
      'assets/preparation_templates/category_templates.json': '''
{"计算机类":{"phases":[{"key":"proposal_writing","required_tasks":[{"template_key":"cs_impl","title":"实现","estimated_hours":16}],"optional_tasks":[]}]}}''',
      'assets/preparation_templates/competition_overrides.json': '{}',
    });
    final p = LocalPreparationTemplateProvider(bundle: bundle);
    final t = await p.load(
      timelineType: CompetitionTimelineType.submission,
      includeDefense: false,
      category: '计算机类',
      competitionId: 'comp_x',
    );
    final writing = t.phases.firstWhere((p) => p.key == 'proposal_writing');
    expect(writing.requiredTasks.any((t) => t.templateKey == 'cs_impl'), isTrue);
    // Dart 必做仍在
    expect(writing.requiredTasks.any((t) => t.templateKey == 'draft'), isTrue);
  });

  test('JSON 缺失时降级到 Dart 默认', () async {
    final bundle = _StubBundle({}); // 两个 asset 都缺
    final p = LocalPreparationTemplateProvider(bundle: bundle);
    final t = await p.load(
      timelineType: CompetitionTimelineType.submission,
      includeDefense: false,
      category: '计算机类',
      competitionId: 'comp_x',
    );
    expect(t.phases.length, 4); // 提交型无答辩 4 阶段
  });

  test('赛事覆盖追加任务', () async {
    final bundle = _StubBundle({
      'assets/preparation_templates/category_templates.json': '{}',
      'assets/preparation_templates/competition_overrides.json': '''
{"comp_icpc":{"phases":[{"key":"proposal_writing","required_tasks":[{"template_key":"icpc_train","title":"训练","estimated_hours":30}],"optional_tasks":[]}]}}''',
    });
    final p = LocalPreparationTemplateProvider(bundle: bundle);
    final t = await p.load(
      timelineType: CompetitionTimelineType.submission,
      includeDefense: false,
      category: '计算机类',
      competitionId: 'comp_icpc',
    );
    final writing = t.phases.firstWhere((p) => p.key == 'proposal_writing');
    expect(writing.requiredTasks.any((t) => t.templateKey == 'icpc_train'), isTrue);
  });

  test('窗口型只加载窗口骨架阶段', () async {
    final provider = LocalPreparationTemplateProvider(bundle: _StubBundle({}));
    final t = await provider.load(
      timelineType: CompetitionTimelineType.eventWindow,
      includeDefense: false,
      category: '计算机类',
      competitionId: 'comp_icpc',
    );
    final keys = t.phases.map((p) => p.key).toSet();
    expect(keys, containsAll(['team_formation', 'rules_review', 'skill_training', 'mock_event', 'final_check']));
    expect(keys, isNot(contains('proposal_writing')));
    expect(keys, isNot(contains('defense_prep')));
  });

  test('提交型无答辩不生成 defense_prep', () async {
    final provider = LocalPreparationTemplateProvider(bundle: _StubBundle({}));
    final t = await provider.load(
      timelineType: CompetitionTimelineType.submission,
      includeDefense: false,
      category: '计算机类',
      competitionId: 'comp_x',
    );
    expect(t.phases.map((p) => p.key), isNot(contains('defense_prep')));
  });

  test('提交型有答辩追加 defense_prep', () async {
    final provider = LocalPreparationTemplateProvider(bundle: _StubBundle({}));
    final t = await provider.load(
      timelineType: CompetitionTimelineType.submission,
      includeDefense: true,
      category: '计算机类',
      competitionId: 'comp_x',
    );
    expect(t.phases.map((p) => p.key), contains('defense_prep'));
  });
}
