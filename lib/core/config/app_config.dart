import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DataSource { mock, ai, http }

class FeatureFlags {
  const FeatureFlags({this.showMatchScore = false, this.showAiTrace = false});

  final bool showMatchScore;
  final bool showAiTrace; // 演示模式：记录并展示 AI 调用快照

  FeatureFlags copyWith({bool? showMatchScore, bool? showAiTrace}) =>
      FeatureFlags(
        showMatchScore: showMatchScore ?? this.showMatchScore,
        showAiTrace: showAiTrace ?? this.showAiTrace,
      );
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

  AppConfig copyWith({
    DataSource? dataSource,
    String? appVersion,
    FeatureFlags? featureFlags,
    LlmConfig? llm,
  }) => AppConfig(
    dataSource: dataSource ?? this.dataSource,
    appVersion: appVersion ?? this.appVersion,
    featureFlags: featureFlags ?? this.featureFlags,
    llm: llm ?? this.llm,
  );

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

/// 启动注入的初值（main 用 dart-define 解析后 override；测试可 override）。
/// 未 override 时为默认 mock 配置。
final initialAppConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

/// 运行时可变的应用配置：允许评委现场在 mock/ai 间切换、开关演示模式。
class AppConfigController extends Notifier<AppConfig> {
  @override
  AppConfig build() => ref.watch(initialAppConfigProvider);

  /// 切数据源；切 ai 仅在已配置 key 时允许（否则忽略，保持原值）。
  void setDataSource(DataSource ds) {
    if (ds == DataSource.ai && !state.llm.isConfigured) return;
    state = state.copyWith(dataSource: ds);
  }

  void setShowAiTrace(bool enabled) {
    state = state.copyWith(
      featureFlags: state.featureFlags.copyWith(showAiTrace: enabled),
    );
  }
}

final appConfigProvider = NotifierProvider<AppConfigController, AppConfig>(
  AppConfigController.new,
);
