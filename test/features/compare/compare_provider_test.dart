import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/repositories/comparison_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/features/compare/providers/compare_provider.dart';

class _FakeProfessorRepository implements ProfessorRepository {
  @override
  Future<Result<Professor>> getProfessor(String professorId) async {
    if (professorId == 'missing') return const Failure(NotFoundException());
    return Success(
      Professor(
        id: professorId,
        name: '导师$professorId',
        university: 'U',
        college: 'C',
        title: '教授',
        researchFields: const ['方向'],
      ),
    );
  }
}

class _FakeComparisonRepository implements ComparisonRepository {
  _FakeComparisonRepository(this.response);

  final Future<Result<ComparisonReport>> response;
  List<Professor>? lastProfessors;

  @override
  Future<Result<ComparisonReport>> compare({
    required List<Professor> professors,
  }) {
    lastProfessors = professors;
    return response;
  }
}

ComparisonReport _report(List<String> ids) => ComparisonReport(
  professorIds: ids,
  rows: const [
    ComparisonRow(dimension: '研究方向', cells: {}),
  ],
  summary: 's',
  suggestion: 'g',
);

ProviderContainer _container(ComparisonRepository repo) => ProviderContainer(
  overrides: [
    professorRepositoryProvider.overrideWithValue(_FakeProfessorRepository()),
    comparisonRepositoryProvider.overrideWithValue(repo),
  ],
);

void main() {
  test('2 位有效导师 -> ready 且携带 report 与 professors', () async {
    final repo = _FakeComparisonRepository(
      Future.value(Success(_report(['p_001', 'p_002']))),
    );
    final container = _container(repo);
    addTearDown(container.dispose);

    await container.read(compareProvider.notifier).load(['p_001', 'p_002']);
    final state = container.read(compareProvider);

    expect(state.status, CompareStatus.ready);
    expect(state.report, isNotNull);
    expect(state.professors.map((p) => p.id).toList(), ['p_001', 'p_002']);
    expect(repo.lastProfessors, hasLength(2));
  });

  test('少于 2 位 -> error（不调用对比仓储）', () async {
    final repo = _FakeComparisonRepository(
      Future.value(Success(_report(['p_001']))),
    );
    final container = _container(repo);
    addTearDown(container.dispose);

    await container.read(compareProvider.notifier).load(['p_001']);
    final state = container.read(compareProvider);

    expect(state.status, CompareStatus.error);
    expect(state.message, contains('2-3'));
    expect(repo.lastProfessors, isNull);
  });

  test('多于 3 位 -> error', () async {
    final repo = _FakeComparisonRepository(
      Future.value(Success(_report(const []))),
    );
    final container = _container(repo);
    addTearDown(container.dispose);

    await container
        .read(compareProvider.notifier)
        .load(['p_001', 'p_002', 'p_003', 'p_004']);

    expect(container.read(compareProvider).status, CompareStatus.error);
    expect(repo.lastProfessors, isNull);
  });

  test('有效导师不足 2（解析失败被丢弃）-> error', () async {
    final repo = _FakeComparisonRepository(
      Future.value(Success(_report(const []))),
    );
    final container = _container(repo);
    addTearDown(container.dispose);

    await container.read(compareProvider.notifier).load(['p_001', 'missing']);

    expect(container.read(compareProvider).status, CompareStatus.error);
    expect(repo.lastProfessors, isNull);
  });

  test('对比仓储失败 -> error 携带文案', () async {
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

    completer.complete(Success(_report(['p_001', 'p_002'])));
    await future;
    expect(container.read(compareProvider).status, CompareStatus.ready);
  });
}
