import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_outreach_email_repository.dart';
import 'package:scho_navi/data/local/local_profile_repository.dart';
import 'package:scho_navi/data/mock/mock_outreach_email_repository.dart';

Future<ProviderContainer> _container({String apiKey = ''}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (apiKey.isNotEmpty)
        appConfigProvider.overrideWithValue(AppConfig.resolve(apiKey: apiKey)),
    ],
  );
}

void main() {
  test('默认（mock）接 MockOutreachEmailRepository + LocalProfileRepository', () async {
    final container = await _container();
    addTearDown(container.dispose);

    expect(
      container.read(outreachEmailRepositoryProvider),
      isA<MockOutreachEmailRepository>(),
    );
    expect(
      container.read(profileRepositoryProvider),
      isA<LocalProfileRepository>(),
    );
  });

  test('dataSource=ai 接 AiOutreachEmailRepository', () async {
    final container = await _container(apiKey: 'sk-test');
    addTearDown(container.dispose);

    expect(
      container.read(outreachEmailRepositoryProvider),
      isA<AiOutreachEmailRepository>(),
    );
  });
}
