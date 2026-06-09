import '../../core/result/result.dart';
import '../entities/chat_result.dart';

abstract interface class ChatRepository {
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
}
