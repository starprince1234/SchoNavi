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
