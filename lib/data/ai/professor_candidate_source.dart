import '../../domain/entities/professor.dart';
import '../mock/mock_db.dart';

abstract interface class ProfessorCandidateSource {
  List<Professor> candidatesFor(String prompt);
}

class MockDbCandidateSource implements ProfessorCandidateSource {
  MockDbCandidateSource(this._db);

  final MockDb _db;

  @override
  List<Professor> candidatesFor(String prompt) => _db.allProfessors;
}
