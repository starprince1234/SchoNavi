import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/match_analysis_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/match/pages/match_page.dart';

const _professor = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像'],
);

class _FakeProfessorRepo implements ProfessorRepository {
  @override
  Future<Result<Professor>> getProfessor(String professorId) async =>
      const Success(_professor);
}

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo(this._profile);

  UserProfile _profile;

  @override
  UserProfile load() => _profile;

  @override
  Future<void> save(UserProfile profile) async => _profile = profile;

  @override
  Future<void> clear() async {}
}

class _FakeMatchRepo implements MatchAnalysisRepository {
  _FakeMatchRepo(this.analysis);

  final MatchAnalysis analysis;
  int calls = 0;

  @override
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  }) async {
    calls++;
    return Success(analysis);
  }
}

Widget _wrap(_FakeProfileRepo profileRepo, _FakeMatchRepo matchRepo) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const MatchPage(professorId: 'p_001'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      professorRepositoryProvider.overrideWithValue(_FakeProfessorRepo()),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      matchAnalysisRepositoryProvider.overrideWithValue(matchRepo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('生成后显示三段 + 免责提示', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final matchRepo = _FakeMatchRepo(
      const MatchAnalysis(
        professorId: 'p_001',
        summary: '方向较契合。',
        strengths: ['研究方向一致'],
        gaps: ['缺少论文'],
        suggestions: ['补读综述'],
      ),
    );
    await tester.pumpWidget(_wrap(profileRepo, matchRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始匹配分析'));
    await tester.pumpAndSettle();

    expect(find.textContaining('仅供参考'), findsOneWidget);
    expect(find.text('总体匹配'), findsOneWidget);
    expect(find.text('匹配点'), findsOneWidget);
    expect(find.text('差距与短板'), findsOneWidget);
    expect(find.text('准备建议'), findsOneWidget);
    expect(find.text('研究方向一致'), findsOneWidget);
    expect(find.text('缺少论文'), findsOneWidget);
    expect(find.text('补读综述'), findsOneWidget);
  });

  testWidgets('重新生成再次调用仓储', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final matchRepo = _FakeMatchRepo(
      const MatchAnalysis(
        professorId: 'p_001',
        summary: 's',
        strengths: ['a'],
        gaps: ['b'],
        suggestions: ['c'],
      ),
    );
    await tester.pumpWidget(_wrap(profileRepo, matchRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始匹配分析'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新生成'));
    await tester.pumpAndSettle();

    expect(matchRepo.calls, 2);
  });

  testWidgets('有维度时显示雷达与综合分，点轴看解读', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final matchRepo = _FakeMatchRepo(
      const MatchAnalysis(
        professorId: 'p_001',
        summary: '方向较契合。',
        strengths: ['研究方向一致'],
        gaps: ['缺少论文'],
        suggestions: ['补读综述'],
        dimensions: [
          MatchDimension(label: '方向契合', score: 90, comment: '高度重合的方向'),
          MatchDimension(label: '方法匹配', score: 70, comment: 'm'),
          MatchDimension(label: '地域', score: 80, comment: 'r'),
          MatchDimension(label: '学历目标', score: 60, comment: 'd'),
          MatchDimension(label: '产出活跃', score: 50, comment: 'o'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(profileRepo, matchRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始匹配分析'));
    await tester.pumpAndSettle();

    expect(find.text('综合契合度（信息性）'), findsOneWidget);
    await tester.tap(find.text('方向契合'));
    await tester.pumpAndSettle();

    expect(find.text('高度重合的方向'), findsOneWidget);
  });
}
