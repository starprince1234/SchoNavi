import '../core/error/app_exception.dart';
import '../core/result/result.dart';
import '../domain/entities/chat_message.dart';
import '../domain/entities/fork_ref.dart';
import '../domain/repositories/chat_repository.dart';
import 'local/chat_history_store.dart';
import 'mock/mock_db.dart';

/// 封装 forkSession/loadHistory/listForks/deleteFork 四个方法的 store 委托逻辑。
///
/// 同时被 [AiChatRepository] 与 [MockChatRepository] 复用，消除 verbatim
/// duplication。Http 实现不接 store，不使用本 mixin。
mixin ChatForkMixin on ChatRepository {
  ChatHistoryStore get historyStore;
  MockDb get db;

  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) async {
    try {
      final existing =
          await historyStore.findFork(sourceSessionId, professorId);
      if (existing != null) return Success(existing.forkId);
      final forkId = 'f_${sourceSessionId}_$professorId';
      final source = await historyStore.load(sourceSessionId) ?? const [];
      await historyStore.save(forkId, source);
      final prof = db.getProfessor(professorId);
      await historyStore.saveFork(ForkRef(
        forkId: forkId,
        mainSessionId: sourceSessionId,
        professorId: professorId,
        professorName: prof?.name ?? '该导师',
        university: prof?.university ?? '',
        college: prof?.college,
        createdAt: DateTime.now(),
      ));
      return Success(forkId);
    } catch (_) {
      return Failure(const UnknownException());
    }
  }

  @override
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  }) async {
    try {
      return Success(await historyStore.load(sessionId) ?? const []);
    } catch (_) {
      return Failure(const UnknownException());
    }
  }

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) async {
    try {
      return Success(await historyStore.listForks(mainSessionId));
    } catch (_) {
      return Failure(const UnknownException());
    }
  }

  @override
  Future<Result<void>> deleteFork({required String forkId}) async {
    try {
      await historyStore.deleteFork(forkId);
      return const Success(null);
    } catch (_) {
      return Failure(const UnknownException());
    }
  }
}
