import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/dto/recommendation_dtos.dart';
import 'package:scho_navi/domain/entities/match_level.dart';

void main() {
  final json = <String, dynamic>{
    'session_id': 's_123',
    'query_understanding': {
      'research_interests': ['医学影像', '计算机视觉'],
      'preferred_locations': ['上海'],
      'preferred_universities': <String>[],
      'degree_stage': '硕士',
      'uncertainties': ['未明确是否偏理论或应用'],
    },
    'recommendations': [
      {
        'professor_id': 'p_001',
        'name': '张三',
        'university': '上海交通大学',
        'college': '电子信息与电气工程学院',
        'title': '教授',
        'research_fields': ['医学影像', '计算机视觉', '深度学习'],
        'homepage_url': 'https://example.edu.cn',
        'match_level': '高',
        'match_score': 0.91,
        'reason': '方向高度相关。',
        'limitations': ['公开资料中未明确招生信息'],
      },
    ],
    'follow_up_questions': ['你更倾向理论还是应用？'],
  };

  test('RecommendationResultDto round-trips via toJson', () {
    final dto = RecommendationResultDto.fromJson(json);
    expect(dto.toJson(), equals(json));
  });

  test('toEntity maps nested objects and enum', () {
    final result = RecommendationResultDto.fromJson(json).toEntity();
    expect(result.sessionId, 's_123');
    expect(result.queryUnderstanding.researchInterests, ['医学影像', '计算机视觉']);
    expect(result.queryUnderstanding.degreeStage, '硕士');
    expect(result.recommendations.single.matchLevel, MatchLevel.high);
    expect(result.recommendations.single.matchScore, 0.91);
    expect(result.followUpQuestions, ['你更倾向理论还是应用？']);
  });
}
