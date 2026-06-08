import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/recommendation_result.dart';

/// 按 prompt 取推荐。Success → 数据；Failure → throw（由 AsyncValue 捕获）。
final recommendationProvider =
    FutureProvider.family<RecommendationResult, String>((ref, prompt) async {
      final repo = ref.watch(recommendationRepositoryProvider);
      final result = await repo.getRecommendations(prompt: prompt);
      return switch (result) {
        Success(:final data) => data,
        Failure(:final error) => throw error,
      };
    });
