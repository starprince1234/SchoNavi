import '../../domain/entities/preparation_config.dart';
import '../../domain/entities/preparation_plan.dart';
import '../../domain/repositories/preparation_config_repository.dart';

class MockPreparationConfigRepository implements PreparationConfigRepository {
  const MockPreparationConfigRepository();

  static const config = PreparationConfig(
    categoryAliases: {
      '电子信息类': '电子与信息类',
      '创新创业类': '综合与创业类',
      '综合创业类': '综合与创业类',
    },
    timelineDefaults: {
      'comp_icpc': CompetitionTimelineType.eventWindow,
      'comp_lanqiao': CompetitionTimelineType.eventWindow,
    },
    priorExperienceOptions: ['从没参加', '参加过未获奖', '获得校级以上奖'],
    domainFamiliarityOptions: ['不熟', '一般', '熟悉'],
  );

  @override
  Future<PreparationConfig> fetch() async => config;
}
