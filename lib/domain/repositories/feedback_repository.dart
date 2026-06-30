import '../../core/result/result.dart';
import '../entities/feedback.dart';

/// 用户反馈提交仓储。
abstract class FeedbackRepository {
  Future<Result<void>> submit(Feedback feedback);
}
