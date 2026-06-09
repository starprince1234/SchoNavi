import '../../core/result/result.dart';
import '../entities/chat_result.dart';

abstract interface class ChatRepository {
  /// 发送一条追问消息，返回助手回答（非流式，V0.2）。
  /// [sessionId] 维持多轮上下文；[professorId] 可锚定某位导师。
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  });
}
