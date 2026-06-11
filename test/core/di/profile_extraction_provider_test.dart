import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_profile_extraction_repository.dart';

void main() {
  test('默认（mock，无 key）也接 AiProfileExtractionRepository（分析类恒 AI）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(profileExtractionRepositoryProvider),
      isA<AiProfileExtractionRepository>(),
    );
  });

  test('dataSource=ai 接 AiProfileExtractionRepository', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(profileExtractionRepositoryProvider),
      isA<AiProfileExtractionRepository>(),
    );
  });
}
