import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DataSource { mock, http }

class FeatureFlags {
  const FeatureFlags({this.showMatchScore = false});

  final bool showMatchScore;
}

class AppConfig {
  const AppConfig({
    this.dataSource = DataSource.mock,
    this.appVersion = '0.1.0',
    this.featureFlags = const FeatureFlags(),
  });

  final DataSource dataSource;
  final String appVersion;
  final FeatureFlags featureFlags;
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());
