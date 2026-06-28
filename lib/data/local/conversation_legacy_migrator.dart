import '../../core/storage/local_store.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/fork_ref.dart';
import 'drift_conversation_store.dart';
import 'local_chat_history_store.dart';
import 'local_history_repository.dart';

class ConversationLegacyMigrator {
  ConversationLegacyMigrator({required this.store, required this.legacyStore});

  static const migrationKey = 'legacy_shared_preferences_v1';

  final DriftConversationStore store;
  final LocalStore legacyStore;
  Future<void>? _migration;

  Future<void> migrateIfNeeded() => _migration ??= _migrate();

  Future<void> _migrate() async {
    if (await store.metadata(migrationKey) == 'done') return;

    final rawHistory =
        legacyStore.getJsonList(LocalHistoryRepository.storageKey) ?? const [];
    final chatStore = LocalChatHistoryStore(legacyStore);
    final mainIds = <String, String>{};
    final mainMessages = <String, List<ChatMessage>>{};
    final forks = _readForks();

    await store.db.transaction(() async {
      for (final entry in rawHistory.whereType<Map>()) {
        final json = Map<String, dynamic>.from(entry);
        if ((json['type'] as String? ?? 'mentor') != 'mentor') continue;
        final legacyId = json['session_id'] as String?;
        if (legacyId == null || legacyId.isEmpty) continue;
        final messages =
            await chatStore.load(legacyId) ?? const <ChatMessage>[];
        final existing = await store.getSession(legacyId);
        final session =
            existing ??
            await store.createSession(
              title: json['prompt'] as String?,
              legacyContextIncomplete: messages.isEmpty,
            );
        if (existing == null) {
          await store.saveAlias(legacyId, session.id);
          await store.importLegacyMessages(session.id, messages);
        }
        mainIds[legacyId] = session.id;
        mainMessages[legacyId] = messages;
      }

      for (final fork in forks) {
        if (await store.getSession(fork.forkId) != null) continue;
        final sourceId = mainIds[fork.mainSessionId];
        if (sourceId == null) continue;
        var sourceTurnId = await store.latestRecommendationTurnForProfessor(
          sourceId,
          fork.professorId,
        );
        var incomplete = false;
        if (sourceTurnId == null) {
          sourceTurnId = await store.latestTurnId(sourceId);
          incomplete = true;
        }
        if (sourceTurnId == null) continue;

        final allForkMessages =
            await chatStore.load(fork.forkId) ?? const <ChatMessage>[];
        final branchMessages = _stripCommonPrefix(
          mainMessages[fork.mainSessionId] ?? const [],
          allForkMessages,
        );
        await store.importLegacyFork(
          sourceSessionId: sourceId,
          sourceTurnId: sourceTurnId,
          professorId: fork.professorId,
          branchMessages: branchMessages,
          legacyId: fork.forkId,
          contextIncomplete: incomplete,
        );
      }
    });

    // Keep competition entries in the legacy search-history repository until
    // competition history is moved to its own structured table.
    final competitions = rawHistory.where((entry) {
      if (entry is! Map) return false;
      return Map<String, dynamic>.from(entry)['type'] == 'competition';
    }).toList();
    await legacyStore.setJsonList(
      LocalHistoryRepository.storageKey,
      competitions,
    );
    for (final legacyId in mainIds.keys) {
      await legacyStore.remove('chat_history_$legacyId');
    }
    for (final fork in forks) {
      await legacyStore.remove('chat_history_${fork.forkId}');
    }
    await legacyStore.remove('chat_forks');
    await store.setMetadata(migrationKey, 'done');
  }

  List<ForkRef> _readForks() {
    final raw = legacyStore.getJsonList('chat_forks') ?? const [];
    return raw
        .map((entry) {
          if (entry is! Map) return null;
          final json = Map<String, dynamic>.from(entry);
          final forkId = json['fork_id'] as String?;
          final mainId = json['main_session_id'] as String?;
          final professorId = json['professor_id'] as String?;
          if (forkId == null ||
              forkId.isEmpty ||
              mainId == null ||
              mainId.isEmpty ||
              professorId == null ||
              professorId.isEmpty) {
            return null;
          }
          return ForkRef(
            forkId: forkId,
            mainSessionId: mainId,
            professorId: professorId,
            professorName: json['professor_name'] as String? ?? '该导师',
            university: json['university'] as String? ?? '',
            college: json['college'] as String?,
            createdAt:
                DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
          );
        })
        .whereType<ForkRef>()
        .toList(growable: false);
  }

  List<ChatMessage> _stripCommonPrefix(
    List<ChatMessage> source,
    List<ChatMessage> fork,
  ) {
    var index = 0;
    while (index < source.length && index < fork.length) {
      final a = source[index];
      final b = fork[index];
      if (a.role != b.role || a.content != b.content || a.kind != b.kind) break;
      index++;
    }
    return fork.sublist(index);
  }
}
