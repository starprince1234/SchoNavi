import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition.dart';
import 'package:scho_navi/domain/repositories/profile_extraction_repository.dart';
import 'package:scho_navi/features/profile/providers/achievements_extraction_provider.dart';

class _FakeExtract implements ProfileExtractionRepository {
  @override
  Future<Result<AchievementDraft>> extract({required String rawText}) async =>
      const Success(
        AchievementDraft(competitions: [Competition(name: 'ACM 区域赛')]),
      );
}

void main() {
  test('extract 成功后 state 为含数据的 AsyncData', () async {
    final container = ProviderContainer(
      overrides: [
        profileExtractionRepositoryProvider.overrideWithValue(_FakeExtract()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(achievementsExtractionProvider.notifier)
        .extract('自述文本');

    final state = container.read(achievementsExtractionProvider);
    expect(state.value?.competitions.single.name, 'ACM 区域赛');
  });
}
