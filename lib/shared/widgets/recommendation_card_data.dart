import '../../domain/entities/match_level.dart';

/// 推荐卡种类。
enum RecommendationKind { mentor, competition }

/// 纯展示模型：横滑卡与列表卡共用的渲染数据。
///
/// 领域实体（Recommendation / RecommendedCompetition）经 Mapper 转换为本类，
/// 组件不感知领域；点击/收藏/打开官网等回调由父层注入。
class RecommendationCardData {
  const RecommendationCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.matchScore,
    required this.reason,
    required this.kind,
    this.openUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> tags;
  final double matchScore; // 0.0–1.0
  final String reason;
  final String? openUrl;
  final RecommendationKind kind;

  /// 由 matchScore 派生等级。
  MatchLevel get matchLevel => MatchLevel.fromScore(matchScore);
}
