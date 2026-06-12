import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';

void main() {
  test('no api key resolves to mock', () {
    final cfg = AppConfig.resolve(apiKey: '');

    expect(cfg.dataSource, DataSource.mock);
    expect(cfg.llm.isConfigured, isFalse);
  });

  test('api key resolves to ai and keeps baseUrl/model', () {
    final cfg = AppConfig.resolve(
      apiKey: 'sk-x',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
    );

    expect(cfg.dataSource, DataSource.ai);
    expect(cfg.llm.apiKey, 'sk-x');
    expect(cfg.llm.baseUrl, 'https://api.deepseek.com');
    expect(cfg.llm.model, 'deepseek-chat');
  });
}
