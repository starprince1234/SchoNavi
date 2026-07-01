import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/competition_recommendation_result.dart';
import '../../profile/providers/profile_provider.dart';

final competitionRecommendationProvider =
    FutureProvider.family<CompetitionRecommendationResult, String>((
      ref,
      prompt,
    ) async {
      final profile = ref.watch(profileProvider);
      final repo = ref.watch(competitionRecommendationRepositoryProvider);
      final result = await repo.getRecommendations(
        prompt: prompt,
        profile: profile,
      );
      return switch (result) {
        Success(:final data) => () {
          if (data.recommendations.isNotEmpty) {
            unawaited(
              ref
                  .read(historyRepositoryProvider)
                  .addFromCompetitionResult(prompt: prompt, result: data),
            );
          }
          return data;
        }(),
        Failure(:final error) => throw error,
      };
    });
