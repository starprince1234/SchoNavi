import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/ai/ai_chat_repository.dart';
import '../../data/ai/ai_comparison_repository.dart';
import '../../data/ai/ai_outreach_email_repository.dart';
import '../../data/ai/ai_recommendation_repository.dart';
import '../../data/ai/professor_candidate_source.dart';
import '../../data/local/local_favorite_repository.dart';
import '../../data/local/local_history_repository.dart';
import '../../data/local/local_profile_repository.dart';
import '../../data/mock/mock_chat_repository.dart';
import '../../data/mock/mock_comparison_repository.dart';
import '../../data/mock/mock_db.dart';
import '../../data/mock/mock_outreach_email_repository.dart';
import '../../data/mock/mock_professor_repository.dart';
import '../../data/mock/mock_recommendation_repository.dart';
import '../../domain/entities/favorite_item.dart';
import '../../domain/entities/search_history_item.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/comparison_repository.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/outreach_email_repository.dart';
import '../../domain/repositories/professor_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../ai/deepseek_llm_client.dart';
import '../ai/llm_client.dart';
import '../config/app_config.dart';
import '../launcher/link_launcher.dart';
import '../launcher/url_launcher_link_launcher.dart';
import '../storage/local_store.dart';
import '../storage/shared_preferences_local_store.dart';

final mockDbProvider = Provider<MockDb>((ref) => MockDb());

final dioProvider = Provider<Dio>((ref) => Dio());

final llmClientProvider = Provider<LlmClient>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return DeepSeekLlmClient(
    dio: ref.watch(dioProvider),
    apiKey: cfg.llm.apiKey,
    baseUrl: cfg.llm.baseUrl,
    model: cfg.llm.model,
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
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.mock:
      return MockComparisonRepository();
    case DataSource.ai:
      return AiComparisonRepository(ref.watch(llmClientProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => LocalProfileRepository(ref.watch(localStoreProvider)),
);

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
  final repo = LocalFavoriteRepository(ref.watch(localStoreProvider));
  ref.onDispose(repo.dispose);
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
  final repo = LocalHistoryRepository(ref.watch(localStoreProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final searchHistoryProvider = StreamProvider<List<SearchHistoryItem>>((ref) {
  return ref.watch(historyRepositoryProvider).watch();
});
