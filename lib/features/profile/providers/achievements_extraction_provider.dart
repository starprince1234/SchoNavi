import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/repositories/profile_extraction_repository.dart';

class AchievementsExtractionController
    extends Notifier<AsyncValue<AchievementDraft?>> {
  @override
  AsyncValue<AchievementDraft?> build() => const AsyncData(null);

  Future<void> extract(String rawText) async {
    state = const AsyncLoading();
    final result =
        await ref.read(profileExtractionRepositoryProvider).extract(rawText: rawText);
    state = switch (result) {
      Success(:final data) => AsyncData(data),
      Failure(:final error) => AsyncError(error, StackTrace.current),
    };
  }

  void reset() => state = const AsyncData(null);
}

final achievementsExtractionProvider = NotifierProvider<
    AchievementsExtractionController, AsyncValue<AchievementDraft?>>(
  AchievementsExtractionController.new,
);
