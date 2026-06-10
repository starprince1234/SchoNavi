import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/match_analysis_repository.dart';
import 'package:scho_navi/features/match/providers/match_provider.dart';

class _FakeMatchRepo implements MatchAnalysisRepository {
  _FakeMatchRepo(this.response);

  Future<Result<MatchAnalysis>> response;
  int calls = 0;
  Professor? lastProfessor;
  UserProfile? lastProfile;

  @override
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  }) {
    calls++;
    lastProfessor = professor;
    lastProfile = profile;
    return response;
  }
}

const _professor = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像'],
);
const _profile = UserProfile(name: '李四', researchInterests: ['医学影像']);
const _analysis = MatchAnalysis(
  professorId: 'p_001',
  summary: '方向较契合。',
  strengths: ['研究方向一致'],
  gaps: ['缺少论文'],
  suggestions: ['补读综述'],
);

ProviderContainer _containerWith(MatchAnalysisRepository repo) =>
    ProviderContainer(
      overrides: [matchAnalysisRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  test('analyze 成功 -> ready 且携带 analysis + 透传入参', () async {
    final repo = _FakeMatchRepo(Future.value(const Success(_analysis)));
    final container = _containerWith(repo);
    addTearDown(container.dispose);

    await container
        .read(matchProvider.notifier)
        .analyze(professor: _professor, profile: _profile);
    final state = container.read(matchProvider);

    expect(state.status, MatchStatus.ready);
    expect(state.analysis?.summary, contains('契合'));
    expect(repo.lastProfessor?.id, 'p_001');
    expect(repo.lastProfile?.name, '李四');
  });

  test('analyze 失败 -> error 且携带文案', () async {
    final container = _containerWith(
      _FakeMatchRepo(Future.value(const Failure(ServerException()))),
    );
    addTearDown(container.dispose);

    await container
        .read(matchProvider.notifier)
        .analyze(professor: _professor, profile: _profile);
    final state = container.read(matchProvider);

    expect(state.status, MatchStatus.error);
    expect(state.message, '服务异常，请稍后重试');
  });

  test('analyze 期间为 analyzing', () async {
    final completer = Completer<Result<MatchAnalysis>>();
    final container = _containerWith(_FakeMatchRepo(completer.future));
    addTearDown(container.dispose);

    final future = container
        .read(matchProvider.notifier)
        .analyze(professor: _professor, profile: _profile);
    expect(container.read(matchProvider).status, MatchStatus.analyzing);

    completer.complete(const Success(_analysis));
    await future;
    expect(container.read(matchProvider).status, MatchStatus.ready);
  });

  test('重新生成：再次调用仓储', () async {
    final repo = _FakeMatchRepo(Future.value(const Success(_analysis)));
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(matchProvider.notifier);

    await notifier.analyze(professor: _professor, profile: _profile);
    await notifier.analyze(professor: _professor, profile: _profile);

    expect(repo.calls, 2);
  });

  test('start 切换 professor 时重置为 idle', () async {
    final repo = _FakeMatchRepo(Future.value(const Success(_analysis)));
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(matchProvider.notifier);

    notifier.start('p_001');
    await notifier.analyze(professor: _professor, profile: _profile);
    expect(container.read(matchProvider).status, MatchStatus.ready);

    notifier.start('p_002');
    expect(container.read(matchProvider).status, MatchStatus.idle);
    expect(container.read(matchProvider).analysis, isNull);
  });
}
