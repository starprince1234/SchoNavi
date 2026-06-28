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
      matchLevel: MatchLevel.high,
      reason: '方向高度契合',
      limitations: const [],
      homepageUrl: 'https://example.edu/p1',
      matchScore: 0.9,
    );
    final d = r.toCardData();
    expect(d.id, 'p1');
    expect(d.title, '张三');
    expect(d.subtitle, '教授 / 清华大学 / 计算机系');
    expect(d.tags, ['计算机视觉', '自然语言处理']);
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
