import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DataSource { mock, ai, http }

class FeatureFlags {
  const FeatureFlags({this.showMatchScore = false});

  final bool showMatchScore;
}

class AppConfig {
  const AppConfig({
    this.dataSource = DataSource.mock,
    this.appVersion = '0.1.0',
    this.featureFlags = const FeatureFlags(),
    this.llm = const LlmConfig(apiKey: ''),
  });

  final DataSource dataSource;
  final String appVersion;
  final FeatureFlags featureFlags;
  final LlmConfig llm;

  factory AppConfig.resolve({
    required String apiKey,
    String baseUrl = 'https://api.deepseek.com',
    String model = 'deepseek-chat',
    String appVersion = '0.1.0',
  }) {
    final llm = LlmConfig(apiKey: apiKey, baseUrl: baseUrl, model: model);
    return AppConfig(
      dataSource: llm.isConfigured ? DataSource.ai : DataSource.mock,
      appVersion: appVersion,
      llm: llm,
    );
  }
}

class LlmConfig {
  const LlmConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-chat',
  });

  final String apiKey;
  final String baseUrl;
  final String model;

  bool get isConfigured => apiKey.isNotEmpty;
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());
