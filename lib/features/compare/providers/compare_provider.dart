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

    final result = await ref
        .read(comparisonRepositoryProvider)
        .compare(professorIds: ids);
    state = switch (result) {
      Success(:final data) => CompareState(
        status: CompareStatus.ready,
        professors: data.professors,
        report: data,
      ),
      Failure(:final error) => CompareState(
        status: CompareStatus.error,
        message: error.message,
      ),
    };
  }
}

final compareProvider = NotifierProvider<CompareNotifier, CompareState>(
  CompareNotifier.new,
);
