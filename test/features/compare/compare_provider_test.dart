import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/repositories/comparison_repository.dart';
import 'package:scho_navi/features/compare/providers/compare_provider.dart';

const _p1 = Professor(
  id: 'p_001',
  name: '导师p_001',
  university: 'U',
  college: 'C',
  title: '教授',
  researchFields: ['方向'],
);

const _p2 = Professor(
  id: 'p_002',
  name: '导师p_002',
  university: 'U',
  college: 'C',
  title: '教授',
  researchFields: ['方向'],
);

ComparisonReport _report(List<String> ids, {required List<Professor> professors}) => ComparisonReport(
  professorIds: ids,
  professors: professors,
  rows: const [
    ComparisonRow(dimension: '研究方向', cells: {}),
  ],
  summary: 's',
  suggestion: 'g',
);

class _FakeComparisonRepository implements ComparisonRepository {
  _FakeComparisonRepository(this.response);

  final Future<Result<ComparisonReport>> response;
  List<String>? lastIds;

  @override
  Future<Result<ComparisonReport>> compare({
    required List<String> professorIds,
  }) {
    lastIds = professorIds;
    return response;
  }
}

ProviderContainer _container(ComparisonRepository repo) => ProviderContainer(
  overrides: [
    comparisonRepositoryProvider.overrideWithValue(repo),
  ],
);

void main() {
  test('2 位有效导师 -> ready 且携带 report 与 professors', () async {
    final repo = _FakeComparisonRepository(
      Future.value(Success(_report(['p_001', 'p_002'], professors: const [_p1, _p2]))),
    );
    final container = _container(repo);
    addTearDown(container.dispose);

    await container.read(compareProvider.notifier).load(['p_001', 'p_002']);
    final state = container.read(compareProvider);

    expect(state.status, CompareStatus.ready);
    expect(state.report, isNotNull);
    expect(state.professors.map((p) => p.id).toList(), ['p_001', 'p_002']);
    expect(repo.lastIds, ['p_001', 'p_002']);
  });

  test('repository 返回错误 -> error 携带文案', () async {
    final repo = _FakeComparisonRepository(
      Future.value(const Failure(ServerException())),
    );
    final container = _container(repo);
    addTearDown(container.dispose);

    await container.read(compareProvider.notifier).load(['p_001', 'p_002']);
    final state = container.read(compareProvider);

    expect(state.status, CompareStatus.error);
    expect(state.message, '服务异常，请稍后重试');
  });

  test('load 期间为 loading', () async {
    final completer = Completer<Result<ComparisonReport>>();
    final container = _container(_FakeComparisonRepository(completer.future));
    addTearDown(container.dispose);

    final future = container
        .read(compareProvider.notifier)
        .load(['p_001', 'p_002']);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(compareProvider).status, CompareStatus.loading);

    completer.complete(Success(_report(['p_001', 'p_002'], professors: const [_p1, _p2])));
    await future;
    expect(container.read(compareProvider).status, CompareStatus.ready);
  });
}
