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
