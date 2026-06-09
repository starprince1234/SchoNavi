import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/professor.dart';

void main() {
  final db = MockDb();

  test('has at least 36 professor fixtures', () {
    expect(db.allProfessors.length, greaterThanOrEqualTo(36));
  });

  test('real supplemental fixtures have complete display data', () {
    final supplemental = db.allProfessors
        .where((p) => int.parse(p.id.substring(2)) >= 13)
        .toList();
    expect(supplemental.length, greaterThanOrEqualTo(24));

    for (final p in supplemental) {
      expect(_isChineseName(p.name), isTrue, reason: p.name);
      expect(p.university, isNotEmpty, reason: p.id);
      expect(p.college, isNotEmpty, reason: p.id);
      expect(p.title, isNotEmpty, reason: p.id);
      expect(p.researchFields, isNotEmpty, reason: p.id);
      expect(p.bio, isNotNull, reason: p.id);
      expect(p.bio, isNotEmpty, reason: p.id);
      expect(p.homepageUrl, isNotNull, reason: p.id);
      expect(p.homepageUrl, startsWith('http'), reason: p.id);
      expect(p.sourceUrl, isNotNull, reason: p.id);
      expect(p.sourceUrl, startsWith('http'), reason: p.id);
    }
  });

  test('recommend detects interests and locations from prompt', () {
    final result = db.recommend('我想找医学影像和计算机视觉方向的导师，最好在上海，申请硕士');
    expect(result.queryUnderstanding.researchInterests, contains('医学影像'));
    expect(result.queryUnderstanding.preferredLocations, contains('上海'));
    expect(result.queryUnderstanding.degreeStage, '硕士');
    expect(result.recommendations, isNotEmpty);
    final scores = result.recommendations
        .map((r) => r.matchScore ?? 0)
        .toList();
    expect(scores.first, greaterThanOrEqualTo(scores.last));
    expect(result.followUpQuestions, isNotEmpty);
  });

  test('recommend normalizes NLP synonym', () {
    final result = db.recommend('NLP 和大模型方向');
    expect(result.queryUnderstanding.researchInterests, contains('自然语言处理'));
    expect(result.recommendations, isNotEmpty);
  });

  test('recommend matches real BUAA embodied intelligence fixture', () {
    final result = db.recommend('具身智能 机器人 北京 博士');
    expect(result.queryUnderstanding.researchInterests, contains('具身智能'));
    expect(result.queryUnderstanding.preferredLocations, contains('北京'));
    expect(result.queryUnderstanding.degreeStage, '博士');
    expect(result.recommendations.map((r) => r.name), contains('牛建伟'));
  });

  test('recommend matches real NJU LLM fixture', () {
    final result = db.recommend('自然语言处理 大语言模型 南京');
    expect(result.queryUnderstanding.researchInterests, contains('自然语言处理'));
    expect(result.queryUnderstanding.researchInterests, contains('大语言模型'));
    expect(result.queryUnderstanding.preferredLocations, contains('南京'));
    expect(result.recommendations.map((r) => r.name), contains('蒋智威'));
  });

  test('recommend matches real UESTC machine learning fixture in Chengdu', () {
    final result = db.recommend('机器学习 成都');
    expect(result.queryUnderstanding.researchInterests, contains('机器学习'));
    expect(result.queryUnderstanding.preferredLocations, contains('成都'));
    expect(result.recommendations.map((r) => r.name), contains('高艳'));
  });

  test('recommend returns empty list for unrelated prompt', () {
    final result = db.recommend('今天天气怎么样');
    expect(result.recommendations, isEmpty);
  });

  test('getProfessor returns fixture by id, null for unknown', () {
    final Professor? p = db.getProfessor('p_001');
    expect(p, isNotNull);
    expect(db.getProfessor('does_not_exist'), isNull);
  });
}

bool _isChineseName(String name) {
  if (name.isEmpty) return false;
  return name.runes.every((rune) => rune >= 0x4E00 && rune <= 0x9FFF);
}
