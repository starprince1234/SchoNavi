import '../../domain/entities/chat_message.dart';
import '../../domain/entities/fork_ref.dart';

/// 会话历史与 fork 元数据的持久化抽象。
///
/// mock/llm 数据源下用 [LocalChatHistoryStore]（SharedPreferences/JSON）；
/// 未来 http 数据源对接真后端时换实现。读方法异步（LocalStore 写异步）。
abstract class ChatHistoryStore {
  Future<List<ChatMessage>?> load(String sessionId);
  Future<void> save(String sessionId, List<ChatMessage> messages);

  Future<List<ForkRef>> listForks(String mainSessionId);
  Future<ForkRef?> findFork(String mainSessionId, String professorId);
  Future<void> saveFork(ForkRef ref);
  Future<void> deleteFork(String forkId);
}
