import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:scho_navi/data/fixtures/competition_timeline_defaults.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

Future<Map<String, dynamic>> _load(String path) async {
  final raw = await rootBundle.loadString(path);
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 注册 asset bundle（默认即用包内 assets，无需额外 mock）
  });

  test('category_templates.json 可解析且每类别阶段任务结构合法', () async {
    final m = await _load(
      'assets/preparation_templates/category_templates.json',
    );
    expect(m, isNotEmpty);
    for (final entry in m.entries) {
      final phases = (entry.value as Map)['phases'] as List;
      for (final p in phases) {
        final pj = p as Map<String, dynamic>;
        expect(pj['key'], isNotNull);
        final req = (pj['required_tasks'] as List?) ?? const [];
        for (final t in req) {
          expect((t as Map)['template_key'], isNotNull);
          expect((t)['estimated_hours'], isNotNull);
        }
      }
    }
  });

  test('competition_overrides.json 含 comp_icpc', () async {
    final m = await _load(
      'assets/preparation_templates/competition_overrides.json',
    );
    expect(m['comp_icpc'], isNotNull);
  });

  test('override phase keys 全部属窗口型骨架', () async {
    const windowKeys = {
      'team_formation',
      'rules_review',
      'skill_training',
      'mock_event',
      'final_check',
    };
    final m = await _load(
      'assets/preparation_templates/competition_overrides.json',
    );
    for (final competitionId in const ['comp_icpc', 'comp_lanqiao']) {
      final phases = (m[competitionId] as Map)['phases'] as List;
      for (final phase in phases) {
        expect(
          windowKeys,
          contains((phase as Map)['key']),
          reason:
              '$competitionId phase key ${(phase)['key']} not in window skeleton',
        );
      }
    }
  });

  group('competition_timeline_defaults', () {
    test('ICPC 与蓝桥杯默认窗口型', () {
      expect(
        CompetitionTimelineDefaults.defaultFor('comp_icpc'),
        CompetitionTimelineType.eventWindow,
      );
      expect(
        CompetitionTimelineDefaults.defaultFor('comp_lanqiao'),
        CompetitionTimelineType.eventWindow,
      );
    });

    test('未知赛事返回 null', () {
      expect(CompetitionTimelineDefaults.defaultFor('comp_unknown'), isNull);
    });
  });
}
