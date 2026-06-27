import '../../core/storage/local_store.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/fork_ref.dart';
import '../dto/chat_message_dto.dart';
import 'chat_history_store.dart';

class LocalChatHistoryStore implements ChatHistoryStore {
  LocalChatHistoryStore(this._store);

  final LocalStore _store;

  static const _forksKey = 'chat_forks';

  static String _historyKey(String sessionId) => 'chat_history_$sessionId';

  @override
  Future<List<ChatMessage>?> load(String sessionId) async {
    final raw = _store.getJsonList(_historyKey(sessionId));
    if (raw == null) return null;
    var i = 0;
    return raw
        .map((e) =>
            ChatMessageDto.fromJson(e as Map<String, dynamic>).toEntity('m${i++}'))
        .toList();
  }

  @override
  Future<void> save(String sessionId, List<ChatMessage> messages) async {
    await _store.setJsonList(
      _historyKey(sessionId),
      messages.map((m) => ChatMessageDto.fromEntity(m).toJson()).toList(),
    );
  }

  List<ForkRef> _readAllForks() {
    final raw = _store.getJsonList(_forksKey) ?? const [];
    return raw
        .map((e) => _forkFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAllForks(List<ForkRef> forks) async {
    await _store.setJsonList(
      _forksKey,
      forks.map(_forkToJson).toList(),
    );
  }

  @override
  Future<List<ForkRef>> listForks(String mainSessionId) async {
    return _readAllForks()
        .where((f) => f.mainSessionId == mainSessionId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ForkRef?> findFork(
    String mainSessionId,
    String professorId,
  ) async {
    return _readAllForks().cast<ForkRef?>().firstWhere(
          (f) =>
              f!.mainSessionId == mainSessionId &&
              f.professorId == professorId,
          orElse: () => null,
        );
  }

  @override
  Future<void> saveFork(ForkRef ref) async {
    final all = _readAllForks();
    all.removeWhere((f) => f.forkId == ref.forkId);
    all.add(ref);
    await _writeAllForks(all);
  }

  @override
  Future<void> deleteFork(String forkId) async {
    final all = _readAllForks();
    all.removeWhere((f) => f.forkId == forkId);
    await _writeAllForks(all);
    await _store.remove(_historyKey(forkId));
  }

  Map<String, dynamic> _forkToJson(ForkRef f) => <String, dynamic>{
        'fork_id': f.forkId,
        'main_session_id': f.mainSessionId,
        'professor_id': f.professorId,
        'professor_name': f.professorName,
        'university': f.university,
        'college': f.college,
        'created_at': f.createdAt.toIso8601String(),
      };

  ForkRef _forkFromJson(Map<String, dynamic> json) => ForkRef(
        forkId: json['fork_id'] as String? ?? '',
        mainSessionId: json['main_session_id'] as String? ?? '',
        professorId: json['professor_id'] as String? ?? '',
        professorName: json['professor_name'] as String? ?? '',
        university: json['university'] as String? ?? '',
        college: json['college'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
      );
}
