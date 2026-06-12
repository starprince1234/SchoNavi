import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/recommendation_result.dart';
import '../../profile/providers/profile_provider.dart';

/// 按 prompt 取推荐，并注入当前档案（背景感知）。档案变更自动失效重算。
final recommendationProvider =
    FutureProvider.family<RecommendationResult, String>((ref, prompt) async {
      final profile = ref.watch(profileProvider);
      final repo = ref.watch(recommendationRepositoryProvider);
      final result = await repo.getRecommendations(
        prompt: prompt,
        profile: profile,
      );
      return switch (result) {
        Success(:final data) => data,
        Failure(:final error) => throw error,
      };
    });
