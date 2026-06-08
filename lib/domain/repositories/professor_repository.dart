import '../../core/result/result.dart';
import '../entities/professor.dart';

abstract interface class ProfessorRepository {
  Future<Result<Professor>> getProfessor(String professorId);
}
