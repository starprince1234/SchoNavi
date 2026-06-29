import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/assistant_turn.dart';
import '../../../domain/entities/plan_change_card.dart';
import '../../../domain/entities/preparation_plan.dart';
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
}
