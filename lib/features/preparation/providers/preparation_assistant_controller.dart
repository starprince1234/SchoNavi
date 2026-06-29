import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar_date.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/assistant_turn.dart';
import '../../../domain/entities/plan_change_card.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/repositories/preparation_plan_assistant.dart';
import '../../../domain/repositories/preparation_plan_repository.dart';
import '../../../data/local/assistant_history_store.dart';
import 'preparation_providers.dart';

/// 备赛助手抽屉的会话状态（spec §4.1）。不可变；由
/// [PreparationAssistantController] 维护。`sending` 仅内存，不落盘。
@immutable
class PreparationAssistantControllerState {
  const PreparationAssistantControllerState({
    required this.currentPlan,
    required this.turns,
    required this.sending,
    required this.expectedRevisions,
    required this.cardStatuses,
    required this.applying,
    required this.cardErrors,
  });

  final PreparationPlan? currentPlan;
  final List<AssistantTurn> turns;
  final bool sending;
  final Map<String, int> expectedRevisions;
  final Map<String, Map<String, ChangeCardStatus>> cardStatuses;
  final Set<String> applying;
  final Map<String, String> cardErrors;

  static const empty = PreparationAssistantControllerState(
    currentPlan: null,
    turns: [],
    sending: false,
    expectedRevisions: {},
    cardStatuses: {},
    applying: {},
    cardErrors: {},
  );

  PreparationAssistantControllerState copyWith({
    PreparationPlan? currentPlan,
    List<AssistantTurn>? turns,
    bool? sending,
    Map<String, int>? expectedRevisions,
    Map<String, Map<String, ChangeCardStatus>>? cardStatuses,
    Set<String>? applying,
    Map<String, String>? cardErrors,
  }) =>
      PreparationAssistantControllerState(
        currentPlan: currentPlan ?? this.currentPlan,
        turns: turns ?? this.turns,
        sending: sending ?? this.sending,
        expectedRevisions: expectedRevisions ?? this.expectedRevisions,
        cardStatuses: cardStatuses ?? this.cardStatuses,
        applying: applying ?? this.applying,
        cardErrors: cardErrors ?? this.cardErrors,
      );
}

/// 备赛助手会话 controller（spec §4）。非 autoDispose——关闭抽屉不销毁 state，
/// 在途请求跨关闭继续执行并落盘。按 planId 家族化（构造注入 planId）。
class PreparationAssistantController
    extends Notifier<PreparationAssistantControllerState> {
  PreparationAssistantController(this.planId);

  final String planId;

  @override
  PreparationAssistantControllerState build() {
    Future.microtask(() => load());
    return PreparationAssistantControllerState.empty;
  }

  PreparationPlanRepository get _repo =>
      ref.read(preparationPlanRepositoryProvider);
  AssistantHistoryStore get _store =>
      ref.read(assistantHistoryStoreProvider);
  PreparationPlanAssistant get _assistant =>
      ref.read(preparationPlanAssistantProvider);

  Future<void> load() async {
    final plan = _repo.findById(planId);
    final turns = await _store.list(planId);
    final expected = <String, int>{};
    final statuses = <String, Map<String, ChangeCardStatus>>{};
    for (final t in turns) {
      if (t.changeSet != null) {
        expected[t.id] ??= t.changeSet!.basePlanRevision;
        statuses[t.id] ??= Map<String, ChangeCardStatus>.from(t.cardStatuses);
      }
    }
    state = state.copyWith(
      currentPlan: plan,
      turns: turns,
      expectedRevisions: expected,
      cardStatuses: statuses,
    );
  }

  /// 发送一轮用户消息（spec §4.2）。关闭抽屉不取消在途请求——state 由非
  /// autoDispose 的本 controller 持有，跨关闭继续 await 并落盘。发送时读取
  /// 仓库最新计划与 revision（非 load 时快照）。`sending` 仅内存不落盘；
  /// 失败 turn 也落盘（`error:true`，无卡），便于重开看到失败轮。
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    final plan = _repo.findById(planId);
    if (plan == null) return;
    final history = state.turns
        .slice(state.turns.length > 10 ? state.turns.length - 10 : 0)
        .map(
          (t) => AssistantHistoryEntry(
            role: 'user',
            content: t.userMessage,
            cardResults: const <AssistantCardResult>[],
          ),
        )
        .toList();
    final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';
    state = state.copyWith(sending: true);
    final request = PlanAssistantRequest(
      planId: planId,
      calendarToday: CalendarDate.normalize(DateTime.now()),
      basePlanRevision: plan.revision,
      planSnapshot: plan,
      userMessage: trimmed,
      history: history,
      requestId: requestId,
    );
    final result = await _assistant.suggestChanges(request);
    switch (result) {
      case Success(:final data):
        final turn = AssistantTurn(
          id: 'turn_${DateTime.now().millisecondsSinceEpoch}',
          planId: planId,
          userMessage: trimmed,
          reply: data.reply,
          createdAt: DateTime.now().toUtc(),
          cardStatuses: {
            for (final c in data.changeSet.cards) c.id: c.status,
          },
          changeSet: data.changeSet,
          requestId: data.requestId.isNotEmpty ? data.requestId : requestId,
        );
        await _store.append(planId, turn);
        final latest = _repo.findById(planId);
        state = state.copyWith(
          currentPlan: latest,
          sending: false,
          turns: [...state.turns, turn],
          expectedRevisions: {
            ...state.expectedRevisions,
            turn.id: data.changeSet.basePlanRevision,
          },
          cardStatuses: {
            ...state.cardStatuses,
            turn.id: {
              for (final c in data.changeSet.cards) c.id: c.status,
            },
          },
        );
      case Failure():
        final turn = AssistantTurn(
          id: 'turn_${DateTime.now().millisecondsSinceEpoch}_err',
          planId: planId,
          userMessage: trimmed,
          reply: '助手调用失败，请稍后重试。',
          createdAt: DateTime.now().toUtc(),
          cardStatuses: const {},
          error: true,
          requestId: requestId,
        );
        await _store.append(planId, turn);
        state = state.copyWith(
          sending: false,
          turns: [...state.turns, turn],
        );
    }
  }
}

extension _ListSlice<T> on List<T> {
  List<T> slice(int start) => start <= 0 ? List<T>.of(this) : sublist(start);
}
