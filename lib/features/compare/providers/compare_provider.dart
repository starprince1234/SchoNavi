import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/comparison_report.dart';
import '../../../domain/entities/professor.dart';

enum CompareStatus { loading, ready, error }

class CompareState {
  const CompareState({
    required this.status,
    this.professors = const [],
    this.report,
    this.message,
  });

  const CompareState.loading()
    : status = CompareStatus.loading,
      professors = const [],
      report = null,
      message = null;

  final CompareStatus status;
  final List<Professor> professors;
  final ComparisonReport? report;
  final String? message;
}

/// 对比页状态。单屏一次一份对比，故用全局 Notifier + load(ids) 驱动。
class CompareNotifier extends Notifier<CompareState> {
  @override
  CompareState build() => const CompareState.loading();

  Future<void> load(List<String> ids) async {
    state = const CompareState.loading();

    final unique = <String>[];
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty && !unique.contains(trimmed)) {
        unique.add(trimmed);
      }
    }
    if (unique.length < 2 || unique.length > 3) {
      state = const CompareState(
        status: CompareStatus.error,
        message: '请选择 2-3 位导师进行对比',
      );
      return;
    }

    final professorRepo = ref.read(professorRepositoryProvider);
    final professors = <Professor>[];
    for (final id in unique) {
      switch (await professorRepo.getProfessor(id)) {
        case Success(:final data):
          professors.add(data);
        case Failure():
          break;
      }
    }
    if (professors.length < 2) {
      state = const CompareState(
        status: CompareStatus.error,
        message: '未能加载足够的导师信息，请返回重试',
      );
      return;
    }

    final result = await ref
        .read(comparisonRepositoryProvider)
        .compare(professors: professors);
    state = switch (result) {
      Success(:final data) => CompareState(
        status: CompareStatus.ready,
        professors: professors,
        report: data,
      ),
      Failure(:final error) => CompareState(
        status: CompareStatus.error,
        professors: professors,
        message: error.message,
      ),
    };
  }
}

final compareProvider = NotifierProvider<CompareNotifier, CompareState>(
  CompareNotifier.new,
);
