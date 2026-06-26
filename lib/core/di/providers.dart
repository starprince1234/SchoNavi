import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/ai/ai_chat_repository.dart';
import '../../data/ai/ai_comparison_repository.dart';
import '../../data/ai/ai_competition_recommendation_repository.dart';
import '../../data/ai/ai_match_analysis_repository.dart';
import '../../data/ai/ai_outreach_email_repository.dart';
import '../../data/ai/ai_profile_extraction_repository.dart';
import '../../data/ai/ai_recommendation_repository.dart';
import '../../data/ai/llm_recommendation_intent_classifier.dart';
import '../../data/ai/llm_recommendation_need_classifier.dart';
import '../../data/ai/professor_candidate_source.dart';
import '../../data/fixtures/competition_catalog.dart';
import '../../data/http/http_chat_repository.dart';
import '../../data/http/http_comparison_repository.dart';
import '../../data/http/http_competition_recommendation_repository.dart';
import '../../data/http/http_favorite_repository.dart';
import '../../data/http/http_history_repository.dart';
import '../../data/local/local_favorite_repository.dart';
import '../../data/local/local_history_repository.dart';
import '../../data/local/local_profile_repository.dart';
import '../../data/mock/mock_db.dart';
import '../../data/mock/mock_professor_repository.dart';
import '../../data/http/http_home_prompt_repository.dart';
import '../../data/http/http_match_analysis_repository.dart';
import '../../data/http/http_outreach_email_repository.dart';
import '../../data/http/http_professor_repository.dart';
import '../../data/http/http_profile_extraction_repository.dart';
import '../../data/http/http_profile_repository.dart';
import '../../data/http/http_recommendation_need_classifier.dart';
import '../../data/http/http_recommendation_repository.dart';
import '../../data/mock/mock_home_prompt_repository.dart';
import '../../domain/entities/favorite_item.dart';
import '../../domain/entities/home_prompt.dart';
import '../../domain/entities/search_history_item.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/comparison_repository.dart';
import '../../domain/repositories/competition_recommendation_repository.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/home_prompt_repository.dart';
import '../../domain/repositories/match_analysis_repository.dart';
import '../../domain/repositories/outreach_email_repository.dart';
import '../../domain/repositories/professor_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/profile_extraction_repository.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../../shared/utils/recommendation_intent_router.dart';
import '../../shared/utils/recommendation_need_classifier.dart';
import '../ai/deepseek_llm_client.dart';
import '../ai/llm_client.dart';
import '../ai/llm_trace.dart';
import '../ai/missing_llm_client.dart';
import '../config/app_config.dart';
import '../launcher/link_launcher.dart';
import '../launcher/url_launcher_link_launcher.dart';
import '../storage/local_store.dart';
import '../storage/shared_preferences_local_store.dart';

final mockDbProvider = Provider<MockDb>((ref) => MockDb());

final dioProvider = Provider<Dio>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return Dio(
    BaseOptions(
      baseUrl: cfg.api.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 10),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
});

final llmClientProvider = Provider<LlmClient>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.llm.isConfigured) return const MissingLlmClient();
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

final competitionCandidateSourceProvider = Provider<CompetitionCandidateSource>(
  (ref) {
    return const StaticCompetitionCandidateSource();
  },
);

final recommendationIntentClassifierProvider =
    Provider<RecommendationIntentClassifier>((ref) {
      return LlmRecommendationIntentClassifier(ref.watch(llmClientProvider));
    });

/// 对话式推荐：用 LLM 判定追问是否需要新一轮推荐（产卡）。
/// 失败降级为 false（不阻断对话）。见 spec §4.5。
final recommendationNeedClassifierProvider =
    Provider<RecommendationNeedClassifier>((ref) {
      return switch (ref.watch(appConfigProvider).dataSource) {
        DataSource.llm => LlmRecommendationNeedClassifier(
          ref.watch(llmClientProvider),
        ),
        DataSource.http => HttpRecommendationNeedClassifier(
          ref.watch(dioProvider),
        ),
      };
    });

final recommendationRepositoryProvider = Provider<RecommendationRepository>((
  ref,
) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.llm:
      return AiRecommendationRepository(
        llm: ref.watch(llmClientProvider),
        candidates: ref.watch(professorCandidateSourceProvider),
      );
    case DataSource.http:
      return HttpRecommendationRepository(ref.watch(dioProvider));
  }
});

final competitionRecommendationRepositoryProvider =
    Provider<CompetitionRecommendationRepository>((ref) {
      switch (ref.watch(appConfigProvider).dataSource) {
        case DataSource.llm:
          return AiCompetitionRecommendationRepository(
            llm: ref.watch(llmClientProvider),
            candidates: ref.watch(competitionCandidateSourceProvider),
          );
        case DataSource.http:
          return HttpCompetitionRecommendationRepository(
            ref.watch(dioProvider),
          );
      }
    });

final professorRepositoryProvider = Provider<ProfessorRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.llm:
      return MockProfessorRepository(ref.watch(mockDbProvider));
    case DataSource.http:
      return HttpProfessorRepository(ref.watch(dioProvider));
  }
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.llm:
      return AiChatRepository(
        llm: ref.watch(llmClientProvider),
        db: ref.watch(mockDbProvider),
      );
    case DataSource.http:
      return HttpChatRepository(ref.watch(dioProvider));
  }
});

final comparisonRepositoryProvider = Provider<ComparisonRepository>((ref) {
  final professorRepo = ref.watch(professorRepositoryProvider);
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.llm:
      return AiComparisonRepository(
        llm: ref.watch(llmClientProvider),
        professorRepository: professorRepo,
      );
    case DataSource.http:
      return HttpComparisonRepository(ref.watch(dioProvider));
  }
});

final matchAnalysisRepositoryProvider = Provider<MatchAnalysisRepository>((
  ref,
) {
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.llm:
      return AiMatchAnalysisRepository(ref.watch(llmClientProvider));
    case DataSource.http:
      return HttpMatchAnalysisRepository(ref.watch(dioProvider));
  }
});
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.llm:
      return LocalProfileRepository(ref.watch(localStoreProvider));
    case DataSource.http:
      return HttpProfileRepository(ref.watch(dioProvider));
  }
});

final outreachEmailRepositoryProvider = Provider<OutreachEmailRepository>((
  ref,
) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.llm:
      return AiOutreachEmailRepository(ref.watch(llmClientProvider));
    case DataSource.http:
      return HttpOutreachEmailRepository(ref.watch(dioProvider));
  }
});

/// 成果抽取：LLM 模式调用大模型，http 待接入真实后端。
final profileExtractionRepositoryProvider =
    Provider<ProfileExtractionRepository>((ref) {
      final cfg = ref.watch(appConfigProvider);
      return switch (cfg.dataSource) {
        DataSource.llm => AiProfileExtractionRepository(
          ref.watch(llmClientProvider),
        ),
        DataSource.http => HttpProfileExtractionRepository(
          ref.watch(dioProvider),
        ),
      };
    });

/// 首页快捷 prompt 仓库。llm 模式使用本地 mock，http 模式走真实后端。
final homePromptRepositoryProvider = Provider<HomePromptRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return switch (cfg.dataSource) {
    DataSource.llm => const MockHomePromptRepository(),
    DataSource.http => HttpHomePromptRepository(ref.watch(dioProvider)),
  };
});

/// 首页快捷 prompt 列表，按模式（mentor / competition）缓存。
final homePromptsProvider = FutureProvider.family<List<HomePrompt>, String>((
  ref,
  mode,
) {
  return ref.watch(homePromptRepositoryProvider).fetchPrompts(mode);
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
  final cfg = ref.watch(appConfigProvider);
  final FavoriteRepository repo;
  switch (cfg.dataSource) {
    case DataSource.llm:
    case DataSource.http:
      repo = cfg.dataSource == DataSource.http
          ? HttpFavoriteRepository(ref.watch(dioProvider))
          : LocalFavoriteRepository(ref.watch(localStoreProvider));
  }
  ref.onDispose(() {
    if (repo is LocalFavoriteRepository) {
      repo.dispose();
    } else if (repo is HttpFavoriteRepository) {
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
    case DataSource.llm:
    case DataSource.http:
      repo = cfg.dataSource == DataSource.http
          ? HttpHistoryRepository(ref.watch(dioProvider))
          : LocalHistoryRepository(ref.watch(localStoreProvider));
  }
  ref.onDispose(() {
    if (repo is LocalHistoryRepository) {
      repo.dispose();
    } else if (repo is HttpHistoryRepository) {
      repo.dispose();
    }
  });
  return repo;
});

final searchHistoryProvider = StreamProvider<List<SearchHistoryItem>>((ref) {
  return ref.watch(historyRepositoryProvider).watch();
});
