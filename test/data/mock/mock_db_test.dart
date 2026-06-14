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
