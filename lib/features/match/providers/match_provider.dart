import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/match_analysis.dart';
import '../../../domain/entities/professor.dart';
import '../../../domain/entities/user_profile.dart';

enum MatchStatus { idle, analyzing, ready, error }

/// 匹配分析页状态。单屏一次一份分析，用 start 注入导师并在切换时重置。
class MatchState {
  const MatchState({
    required this.professorId,
    required this.status,
    this.analysis,
    this.error,
  });

  const MatchState.initial()
    : professorId = null,
      status = MatchStatus.idle,
      analysis = null,
      error = null;

  final String? professorId;
  final MatchStatus status;
  final MatchAnalysis? analysis;
  final AppException? error;
  String? get message => error?.message;
}

class MatchNotifier extends Notifier<MatchState> {
  @override
  MatchState build() => const MatchState.initial();

  void start(String professorId) {
    if (state.professorId == professorId) return;
    state = MatchState(professorId: professorId, status: MatchStatus.idle);
  }

  Future<void> analyze({
    required Professor professor,
    required UserProfile profile,
  }) async {
    final professorId = state.professorId ?? professor.id;
    state = MatchState(professorId: professorId, status: MatchStatus.analyzing);

    final result = await ref
        .read(matchAnalysisRepositoryProvider)
        .analyze(professor: professor, profile: profile);

    state = switch (result) {
      Success(:final data) => MatchState(
        professorId: professorId,
        status: MatchStatus.ready,
        analysis: data,
      ),
      Failure(:final error) => MatchState(
        professorId: professorId,
        status: MatchStatus.error,
        error: error,
      ),
    };
  }
}

final matchProvider = NotifierProvider<MatchNotifier, MatchState>(
  MatchNotifier.new,
);
