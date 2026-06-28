// test/data/local/local_preparation_template_provider_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/local/local_preparation_template_provider.dart';

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
    final t = await p.load(category: '计算机类');
    final writing = t.phases.firstWhere((p) => p.key == 'proposal_writing');
    expect(writing.requiredTasks.any((t) => t.templateKey == 'cs_impl'), isTrue);
    // Dart 必做仍在
    expect(writing.requiredTasks.any((t) => t.templateKey == 'outline'), isTrue);
  });

  test('JSON 缺失时降级到 Dart 默认', () async {
    final bundle = _StubBundle({}); // 两个 asset 都缺
    final p = LocalPreparationTemplateProvider(bundle: bundle);
    final t = await p.load(category: '计算机类');
    expect(t.phases.length, 5); // Dart 默认 5 阶段
  });

  test('赛事覆盖追加任务', () async {
    final bundle = _StubBundle({
      'assets/preparation_templates/category_templates.json': '{}',
      'assets/preparation_templates/competition_overrides.json': '''
{"comp_icpc":{"phases":[{"key":"proposal_writing","required_tasks":[{"template_key":"icpc_train","title":"训练","estimated_hours":30}],"optional_tasks":[]}]}}''',
    });
    final p = LocalPreparationTemplateProvider(bundle: bundle);
    final t = await p.load(competitionId: 'comp_icpc');
    final writing = t.phases.firstWhere((p) => p.key == 'proposal_writing');
    expect(writing.requiredTasks.any((t) => t.templateKey == 'icpc_train'), isTrue);
  });
}
