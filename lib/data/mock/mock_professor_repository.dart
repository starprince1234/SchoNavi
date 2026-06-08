import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/professor.dart';
import '../../domain/repositories/professor_repository.dart';
import 'mock_db.dart';

class MockProfessorRepository implements ProfessorRepository {
  MockProfessorRepository(this._db);

  final MockDb _db;

  @override
  Future<Result<Professor>> getProfessor(String professorId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final p = _db.getProfessor(professorId);
    if (p == null) return const Failure(NotFoundException());
    return Success(p);
  }
}
