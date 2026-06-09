import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_match_analysis_repository.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

const _professor = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
);

void main() {
  test('三段非空，summary 含导师方向，professorId 回填', () async {
    final repo = MockMatchAnalysisRepository();

    final result = await repo.analyze(
      professor: _professor,
      profile: const UserProfile(name: '李四', researchInterests: ['医学影像']),
    );

    final analysis = (result as Success<MatchAnalysis>).data;
    expect(analysis.professorId, 'p_001');
    expect(analysis.strengths, isNotEmpty);
    expect(analysis.gaps, isNotEmpty);
    expect(analysis.suggestions, isNotEmpty);
    expect(analysis.summary, contains('医学影像'));
  });

  test('学生信息为空也能生成，gaps 提示补充背景', () async {
    final repo = MockMatchAnalysisRepository();

    final result = await repo.analyze(
      professor: _professor,
      profile: const UserProfile(),
    );

    final analysis = (result as Success<MatchAnalysis>).data;
    expect(analysis.gaps, isNotEmpty);
    expect(analysis.gaps.join(), contains('补充'));
    expect(analysis.summary, isNotEmpty);
  });
}
