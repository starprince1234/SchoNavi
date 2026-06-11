import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';
import 'package:scho_navi/domain/entities/competition.dart';
import 'package:scho_navi/domain/entities/research_item.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

void main() {
  test('空 profile isEmpty 为 true', () {
    expect(const UserProfile().isEmpty, isTrue);
  });

  test('任一新字段非空则 isEmpty 为 false', () {
    expect(const UserProfile(gender: Gender.female).isEmpty, isFalse);
    expect(
      const UserProfile(competitions: [Competition(name: 'ACM')]).isEmpty,
      isFalse,
    );
  });

  test('completion 按 7 项命中率计算', () {
    expect(const UserProfile().completion, 0.0);

    const full = UserProfile(
      name: '张三',
      gender: Gender.male,
      school: '上海交通大学',
      major: '计算机',
      targetDegree: '申请硕士',
      score: AcademicScore(gpa: 3.8, scale: 4.0),
      researchInterests: ['人工智能'],
      competitions: [Competition(name: 'ACM 区域赛')],
    );
    expect(full.completion, 1.0);

    // 仅命中 name + gender = 2/7
    const partial = UserProfile(name: '张三', gender: Gender.male);
    expect(partial.completion, closeTo(2 / 7, 1e-9));
  });

  test('copyWith 覆盖指定字段、保留其余', () {
    const base = UserProfile(name: '张三', gender: Gender.male);
    final next = base.copyWith(
      targetDegree: '申请博士',
      research: const [ResearchItem(type: ResearchType.paper, title: 'X')],
    );
    expect(next.name, '张三');
    expect(next.gender, Gender.male);
    expect(next.targetDegree, '申请博士');
    expect(next.research, hasLength(1));
  });
}
