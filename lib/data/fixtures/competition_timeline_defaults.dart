import '../../domain/entities/preparation_plan.dart';

/// 已知赛事的默认时间模型（spec §2.3）。按 competition ID 决定，不靠名称猜。
class CompetitionTimelineDefaults {
  const CompetitionTimelineDefaults._();

  static const Map<String, CompetitionTimelineType> _byId = {
    'comp_icpc': CompetitionTimelineType.eventWindow,
    'comp_lanqiao': CompetitionTimelineType.eventWindow,
  };

  static CompetitionTimelineType? defaultFor(String competitionId) =>
      _byId[competitionId];
}
