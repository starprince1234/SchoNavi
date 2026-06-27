import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';

void main() {
  group('ForkRef', () {
    test('构造与字段', () {
      final ref = ForkRef(
        forkId: 'f_s1_p1',
        mainSessionId: 's1',
        professorId: 'p1',
        professorName: '李卫国',
        university: '清华大学',
        college: '计算机系',
        createdAt: DateTime(2026, 6, 27, 14, 22),
      );
      expect(ref.forkId, 'f_s1_p1');
      expect(ref.mainSessionId, 's1');
      expect(ref.professorId, 'p1');
      expect(ref.professorName, '李卫国');
      expect(ref.university, '清华大学');
      expect(ref.college, '计算机系');
      expect(ref.createdAt, DateTime(2026, 6, 27, 14, 22));
    });

    test('college 可空', () {
      final ref = ForkRef(
        forkId: 'f_s1_p1',
        mainSessionId: 's1',
        professorId: 'p1',
        professorName: '李卫国',
        university: '清华大学',
        college: null,
        createdAt: DateTime(2026, 6, 27),
      );
      expect(ref.college, isNull);
    });
  });
}
