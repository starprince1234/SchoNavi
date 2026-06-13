import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/ai/ai_chat_repository.dart';
import '../../data/ai/ai_comparison_repository.dart';
import '../../data/ai/ai_match_analysis_repository.dart';
import '../../data/ai/ai_outreach_email_repository.dart';
import '../../data/ai/ai_profile_extraction_repository.dart';
import '../../data/ai/ai_recommendation_repository.dart';
import '../../data/ai/professor_candidate_source.dart';
import '../../data/local/local_favorite_repository.dart';
import '../../data/local/local_history_repository.dart';
import '../../data/local/local_profile_repository.dart';
import '../../data/mock/mock_chat_repository.dart';
import '../../data/mock/mock_comparison_repository.dart';
import '../../data/mock/mock_favorite_repository.dart';
import '../../data/mock/mock_history_repository.dart';
import '../../data/mock/mock_match_analysis_repository.dart';
import '../../data/mock/mock_db.dart';
import '../../data/mock/mock_outreach_email_repository.dart';
import '../../data/mock/mock_professor_repository.dart';
import '../../data/mock/mock_profile_extraction_repository.dart';
import '../../data/mock/mock_profile_repository.dart';
import '../../data/mock/mock_recommendation_repository.dart';
import '../../domain/entities/favorite_item.dart';
import '../../domain/entities/search_history_item.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/comparison_repository.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/match_analysis_repository.dart';
import '../../domain/repositories/outreach_email_repository.dart';
import '../../domain/repositories/professor_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/profile_extraction_repository.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../ai/deepseek_llm_client.dart';
import '../ai/llm_client.dart';
import '../ai/llm_trace.dart';
import '../config/app_config.dart';
import '../launcher/link_launcher.dart';
import '../launcher/url_launcher_link_launcher.dart';
import '../storage/local_store.dart';
import '../storage/shared_preferences_local_store.dart';

final mockDbProvider = Provider<MockDb>((ref) => MockDb());

final dioProvider = Provider<Dio>((ref) => Dio());

final llmClientProvider = Provider<LlmClient>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final base = DeepSeekLlmClient(
    dio: ref.watch(dioProvider),
    apiKey: cfg.llm.apiKey,
    baseUrl: cfg.llm.baseUrl,
    model: cfg.llm.model,
  );
  if (!cfg.featureFlags.showAiTrace) return base;
  return TracingLlmClient(
    delegate: base,
    model: cfg.llm.model,
    onTrace: (trace) => ref.read(aiTraceProvider.notifier).record(trace),
  );
});

final professorCandidateSourceProvider = Provider<ProfessorCandidateSource>(
  (ref) => MockDbCandidateSource(ref.watch(mockDbProvider)),
);

final recommendationRepositoryProvider = Provider<RecommendationRepository>((
  ref,
) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
      return MockRecommendationRepository(ref.watch(mockDbProvider));
    case DataSource.ai:
      return AiRecommendationRepository(
        llm: ref.watch(llmClientProvider),
        candidates: ref.watch(professorCandidateSourceProvider),
      );
    case DataSource.http:
      // V1.0：返回 HttpRecommendationRepository(ref.watch(dioClientProvider))
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});

final professorRepositoryProvider = Provider<ProfessorRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
    case DataSource.ai:
      return MockProfessorRepository(ref.watch(mockDbProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
      return MockChatRepository(ref.watch(mockDbProvider));
    case DataSource.ai:
      return AiChatRepository(
        llm: ref.watch(llmClientProvider),
        db: ref.watch(mockDbProvider),
      );
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});

final comparisonRepositoryProvider = Provider<ComparisonRepository>((ref) {
  final professorRepo = ref.watch(professorRepositoryProvider);
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.mock:
      return MockComparisonRepository(professorRepository: professorRepo);
    case DataSource.ai:
      return AiComparisonRepository(
        llm: ref.watch(llmClientProvider),
        professorRepository: professorRepo,
      );
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});

final matchAnalysisRepositoryProvider = Provider<MatchAnalysisRepository>((
  ref,
) {
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.mock:
      return MockMatchAnalysisRepository();
    case DataSource.ai:
      return AiMatchAnalysisRepository(ref.watch(llmClientProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
      return MockProfileRepository();
    case DataSource.ai:
      return LocalProfileRepository(ref.watch(localStoreProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});

final outreachEmailRepositoryProvider = Provider<OutreachEmailRepository>((
  ref,
) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
      return MockOutreachEmailRepository();
    case DataSource.ai:
      return AiOutreachEmailRepository(ref.watch(llmClientProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});

/// 成果抽取：mock 使用本地轻量解析，ai 调用 LLM，http 待接入真实后端。
final profileExtractionRepositoryProvider = Provider<ProfileExtractionRepository>(
  (ref) {
    final cfg = ref.watch(appConfigProvider);
    return switch (cfg.dataSource) {
      DataSource.mock => const MockProfileExtractionRepository(),
      DataSource.ai => AiProfileExtractionRepository(ref.watch(llmClientProvider)),
      DataSource.http => throw UnimplementedError(
        'HTTP data source not wired until V1.0',
      ),
    };
  },
);

/// 在 main() 中用 SharedPreferences.getInstance() 的结果 override。
/// 未 override 直接读取会抛错，提醒接线缺失。
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() with '
    'SharedPreferences.getInstance()',
  ),
);

/// 全应用本地持久化入口。收藏/历史/登录态/首启标记均经此存取。
final localStoreProvider = Provider<LocalStore>(
  (ref) => SharedPreferencesLocalStore(ref.watch(sharedPreferencesProvider)),
);

/// 外链打开（教师主页等）。feature 层只依赖 [LinkLauncher] 接口，便于注入假实现。
final linkLauncherProvider = Provider<LinkLauncher>(
  (ref) => const UrlLauncherLinkLauncher(),
);

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final FavoriteRepository repo;
  switch (cfg.dataSource) {
    case DataSource.mock:
      repo = MockFavoriteRepository();
    case DataSource.ai:
    case DataSource.http:
      repo = LocalFavoriteRepository(ref.watch(localStoreProvider));
  }
  ref.onDispose(() {
    if (repo is MockFavoriteRepository) {
      repo.dispose();
    } else if (repo is LocalFavoriteRepository) {
      repo.dispose();
    }
  });
  return repo;
});

final favoritesProvider = StreamProvider<List<FavoriteItem>>((ref) {
  return ref.watch(favoriteRepositoryProvider).watch();
});

final favoriteStatusProvider = StreamProvider.family<bool, String>((
  ref,
  professorId,
) {
  return ref
      .watch(favoriteRepositoryProvider)
      .watch()
      .map((items) => items.any((item) => item.professorId == professorId));
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final HistoryRepository repo;
  switch (cfg.dataSource) {
    case DataSource.mock:
      repo = MockHistoryRepository();
    case DataSource.ai:
    case DataSource.http:
      repo = LocalHistoryRepository(ref.watch(localStoreProvider));
  }
  ref.onDispose(() {
    if (repo is MockHistoryRepository) {
      repo.dispose();
    } else if (repo is LocalHistoryRepository) {
      repo.dispose();
    }
  });
  return repo;
});

final searchHistoryProvider = StreamProvider<List<SearchHistoryItem>>((ref) {
  return ref.watch(historyRepositoryProvider).watch();
});
