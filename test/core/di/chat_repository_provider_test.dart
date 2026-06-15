import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/http/http_chat_repository.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';

void main() {
  test('default config wires AiChatRepository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(chatRepositoryProvider), isA<AiChatRepository>());
    expect(container.read(chatRepositoryProvider), isA<ChatRepository>());
  });

  test('http config wires HttpChatRepository', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: '', apiBaseUrl: 'https://api.example.com'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(chatRepositoryProvider), isA<HttpChatRepository>());
    expect(container.read(chatRepositoryProvider), isA<ChatRepository>());
  });
}
