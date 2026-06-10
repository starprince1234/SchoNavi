import '../../core/result/result.dart';
import '../entities/match_analysis.dart';
import '../entities/professor.dart';
import '../entities/user_profile.dart';

/// 基于导师事实与学生背景生成信息性匹配分析，不预测录取概率。
abstract interface class MatchAnalysisRepository {
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  });
}
