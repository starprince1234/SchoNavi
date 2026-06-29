import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../data/ai/ai_preparation_personalizer.dart';
import '../../../data/ai/ai_preparation_level_diagnoser.dart';
import '../../../data/http/http_preparation_personalizer.dart';
import '../../../data/http/http_preparation_level_diagnoser.dart';
import '../../../data/local/local_preparation_plan_repository.dart';
import '../../../data/local/local_preparation_template_provider.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/repositories/preparation_plan_repository.dart';
import '../../../domain/repositories/preparation_level_diagnoser.dart';
import '../../../domain/repositories/preparation_template_provider.dart';
import '../../../domain/services/preparation_plan_generator.dart';

/// 备赛计划仓库：基于 [LocalPreparationPlanRepository] + SharedPreferences。
/// 非 autoDispose——跨页面需长期持有；app 关闭时由 [ref.onDispose] 关闭 stream。
final preparationPlanRepositoryProvider = Provider<PreparationPlanRepository>((
  ref,
) {
  final repo = LocalPreparationPlanRepository(ref.watch(localStoreProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

/// 备赛模板提供者：本地 AssetBundle（赛类/赛事 JSON 叠加）。
final preparationTemplateProvider = Provider<PreparationTemplateProvider>(
  (_) => LocalPreparationTemplateProvider(bundle: rootBundle),
);

/// 备赛个性化器：按 [DataSource] 切换 LLM / HTTP 实现。
final preparationPersonalizerProvider = Provider<PreparationPersonalizer>((
  ref,
) {
  return switch (ref.watch(appConfigProvider).dataSource) {
    DataSource.llm => AiPreparationPersonalizer(ref.watch(llmClientProvider)),
    DataSource.http =>
      HttpPreparationPersonalizer(ref.watch(dioProvider)),
  };
});

/// 备赛水平诊断器：按 [DataSource] 切换 LLM / HTTP 实现。
final preparationLevelDiagnoserProvider = Provider<PreparationLevelDiagnoser>((
  ref,
) {
  return switch (ref.watch(appConfigProvider).dataSource) {
    DataSource.llm =>
      AiPreparationLevelDiagnoser(ref.watch(llmClientProvider)),
    DataSource.http =>
      HttpPreparationLevelDiagnoser(ref.watch(dioProvider)),
  };
});

/// 备赛计划生成器：模板 + 个性化器组装 + 排期。
final preparationPlanGeneratorProvider = Provider<PreparationPlanGenerator>(
  (ref) => PreparationPlanGenerator(
    templateProvider: ref.watch(preparationTemplateProvider),
    personalizer: ref.watch(preparationPersonalizerProvider),
  ),
);

/// 备赛计划列表流：仓库 [watch()] 的封装。
final preparationPlanListProvider =
    StreamProvider<List<PreparationPlan>>(
      (ref) => ref.watch(preparationPlanRepositoryProvider).watch(),
    );

/// 指定竞赛的当前 active 计划（同步查询，内存中遍历 list）。
final activePlanForCompetitionProvider =
    Provider.family<PreparationPlan?, String>((ref, competitionId) {
      final repo = ref.watch(preparationPlanRepositoryProvider);
      return repo.activeForCompetition(competitionId);
    });
