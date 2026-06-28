// test/data/fixtures/preparation_templates_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/fixtures/preparation_templates.dart';

void main() {
  test('默认模板含 5 阶段且权重和约为 1', () {
    final t = defaultPreparationTemplate();
    expect(t.phases.length, 5);
    expect(t.phases.map((p) => p.key), contains('team_formation'));
    final sum = t.phases.fold<double>(0, (a, p) => a + p.weight);
    expect((sum - 1.0).abs(), lessThan(0.001));
  });

  test('每阶段至少 1 个必做任务且必做任务有 templateKey', () {
    final t = defaultPreparationTemplate();
    for (final p in t.phases) {
      expect(p.requiredTasks, isNotEmpty);
      for (final task in p.requiredTasks) {
        expect(task.templateKey, isNotNull);
        expect(task.estimatedHours, greaterThan(0));
      }
    }
  });
}
