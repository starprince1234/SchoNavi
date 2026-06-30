import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';

void main() {
  test('no api key resolves to llm mode with unconfigured LLM', () {
    final cfg = AppConfig.resolve(apiKey: '');

    expect(cfg.dataSource, DataSource.llm);
    expect(cfg.llm.isConfigured, isFalse);
  });

  test('api key resolves to llm mode and keeps baseUrl/model', () {
    final cfg = AppConfig.resolve(
      apiKey: 'sk-x',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
    );

    expect(cfg.dataSource, DataSource.llm);
    expect(cfg.llm.apiKey, 'sk-x');
    expect(cfg.llm.baseUrl, 'https://api.deepseek.com');
    expect(cfg.llm.model, 'deepseek-chat');
  });

  test('api base url resolves to http mode and trims trailing slash', () {
    final cfg = AppConfig.resolve(
      apiKey: 'sk-x',
      apiBaseUrl: 'https://api.example.com/',
    );

    expect(cfg.dataSource, DataSource.http);
    expect(cfg.api.baseUrl, 'https://api.example.com');
    expect(cfg.llm.apiKey, 'sk-x');
  });

  test('api base url normalizes accidental api/v1 suffix to origin', () {
    final cfg = AppConfig.resolve(
      apiKey: 'sk-x',
      apiBaseUrl: 'https://api.example.com/api/v1/',
    );

    expect(cfg.dataSource, DataSource.http);
    expect(cfg.api.baseUrl, 'https://api.example.com');
  });
}
