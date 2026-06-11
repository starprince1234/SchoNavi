import '../../core/result/result.dart';
import '../entities/competition.dart';
import '../entities/research_item.dart';

/// 自由文本 → 结构化成果条目（分析类，仅 AI 实现）。
class AchievementDraft {
  const AchievementDraft({this.competitions = const [], this.research = const []});

  final List<Competition> competitions;
  final List<ResearchItem> research;
}

abstract interface class ProfileExtractionRepository {
  Future<Result<AchievementDraft>> extract({required String rawText});
}
