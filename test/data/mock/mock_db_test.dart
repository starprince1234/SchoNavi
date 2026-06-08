import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/professor.dart';

void main() {
  final db = MockDb();

  test('has at least 12 professor fixtures', () {
    expect(db.allProfessors.length, greaterThanOrEqualTo(12));
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
