import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/data/mock/mock_professor_repository.dart';
import 'package:scho_navi/data/mock/mock_recommendation_repository.dart';

void main() {
  final db = MockDb();

  test('MockRecommendationRepository returns Success with results', () async {
    final repo = MockRecommendationRepository(db);
    final res = await repo.getRecommendations(prompt: '医学影像 上海');
    expect(res, isA<Success>());
    final data = (res as Success).data;
    expect(data.recommendations, isNotEmpty);
  });

  test('MockProfessorRepository returns Success for known id', () async {
    final repo = MockProfessorRepository(db);
    final res = await repo.getProfessor('p_001');
    expect(res, isA<Success>());
  });

  test(
    'MockProfessorRepository returns Failure(NotFound) for unknown id',
    () async {
      final repo = MockProfessorRepository(db);
      final res = await repo.getProfessor('nope');
      expect(res, isA<Failure>());
      expect((res as Failure).error, isA<NotFoundException>());
    },
  );
}
