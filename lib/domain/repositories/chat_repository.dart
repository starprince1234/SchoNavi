import '../../core/result/result.dart';
import '../entities/chat_result.dart';
import '../entities/recommendation_result.dart';

/// 对话仓储。
///
/// 改为 `abstract class` 以给 [seedRecommendationTurn] 提供默认空实现，使
/// 无本地会话历史的实现可以安全忽略上下文注入。
abstract class ChatRepository {
  /// 发送一条追问消息，返回助手回答（非流式，mock 直接测用）。
  /// [sessionId] 维持多轮上下文；[professorId] 可锚定某位导师。
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  });

  /// 流式回答：逐段 emit 文本增量；完成或被取消时把已生成整段并入会话历史，
  /// 出错则丢弃半句。失败经 Stream 抛 AppException。
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  });

  /// 把一次完整推荐轮按“用户需求 → 推荐摘要”的顺序写入会话历史。
  ///
  /// 默认空实现适用于由服务端维护会话历史的 HTTP 实现，以及无需历史的 mock。
  void seedRecommendationTurn({
    required String sessionId,
    required String userPrompt,
    required RecommendationResult result,
  }) {}
}
