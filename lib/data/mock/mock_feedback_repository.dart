import '../../core/result/result.dart';
import '../../domain/entities/feedback.dart';
import '../../domain/repositories/feedback_repository.dart';

/// 离线/演示模式反馈仓储:模拟网络延迟后返回成功。
class MockFeedbackRepository implements FeedbackRepository {
  MockFeedbackRepository({this._delay = const Duration(milliseconds: 600)});

  final Duration _delay;

  @override
  Future<Result<void>> submit(Feedback feedback) async {
    await Future<void>.delayed(_delay);
    return const Success(null);
  }
}
