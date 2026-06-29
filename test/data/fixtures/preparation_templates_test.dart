// test/data/fixtures/preparation_templates_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/fixtures/preparation_templates.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

void main() {
  test('提交型默认模板含 4 阶段且权重和约为 1', () {
    final t = defaultPreparationTemplate(CompetitionTimelineType.submission);
    expect(t.phases.length, 4);
    expect(t.phases.map((p) => p.key), contains('team_formation'));
    final sum = t.phases.fold<double>(0, (a, p) => a + p.weight);
    expect((sum - 0.85).abs(), lessThan(0.001)); // 0.15+0.20+0.35+0.15
  });

  test('提交型含答辩追加 defense_prep 且权重和约为 1', () {
    final t = defaultPreparationTemplate(
      CompetitionTimelineType.submission,
      includeDefense: true,
    );
    expect(t.phases.length, 5);
    expect(t.phases.map((p) => p.key), contains('defense_prep'));
    final sum = t.phases.fold<double>(0, (a, p) => a + p.weight);
    expect((sum - 1.0).abs(), lessThan(0.001));
  });

  test('窗口型模板含 5 阶段且权重和约为 1', () {
    final t = defaultPreparationTemplate(CompetitionTimelineType.eventWindow);
    expect(t.phases.length, 5);
    expect(
      t.phases.map((p) => p.key),
      containsAll([
        'team_formation',
        'rules_review',
        'skill_training',
        'mock_event',
        'final_check',
      ]),
    );
    expect(t.phases.map((p) => p.key), isNot(contains('defense_prep')));
    final sum = t.phases.fold<double>(0, (a, p) => a + p.weight);
    expect((sum - 1.0).abs(), lessThan(0.001));
  });

  test('每阶段至少 1 个必做任务且必做任务有 templateKey', () {
    for (final type in CompetitionTimelineType.values) {
      final t = defaultPreparationTemplate(type, includeDefense: true);
      for (final p in t.phases) {
        expect(p.requiredTasks, isNotEmpty);
        for (final task in p.requiredTasks) {
          expect(task.templateKey, isNotNull);
          expect(task.estimatedHours, greaterThan(0));
        }
      }
    }
  });
}
