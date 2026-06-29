import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar_date.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/assistant_turn.dart';
import '../../../domain/entities/plan_change_card.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/repositories/preparation_plan_assistant.dart';
import '../../../domain/services/plan_change_applier.dart';
import '../../chat/widgets/chat_message_bubble.dart';
import '../providers/preparation_providers.dart';
import '../widgets/assistant_turn_message_mapper.dart';
import '../widgets/plan_change_card_view.dart';

/// 备赛日历 AI 助手抽屉（spec §3.4 / P4a.5 + P4b.2）：以 modal bottom sheet
/// 打开，渲染历史轮次（经 [AssistantTurnMessageMapper] + [ChatMessageBubble]）
/// + 当前输入条；发送时构造 [PlanAssistantRequest] 调用助手，成功追加
/// [AssistantTurn] 到历史 store 并渲染 AI 回复（全宽无气泡）与改动卡
/// （横滑 [PlanChangeCardView]）；失败展示 P0 错误态。
///
/// 接受/拒绝（P4b.2）：接受读最新计划 → revision 不匹配则本 change set 剩余
/// pending 卡标 stale；匹配则 [PlanChangeApplier.applyCard] → 仓库 CAS save
/// → 成功标 applied + bump expectedRevision；ConflictException 卡保持 pending
/// + 错误。拒绝标 declined 折叠。状态写回 [AssistantHistoryStore]。
class PreparationAssistantDrawer extends ConsumerStatefulWidget {
  const PreparationAssistantDrawer({
    super.key,
    required this.planId,
    required this.plan,
  });

  final String planId;
  final PreparationPlan plan;

  @override
  ConsumerState<PreparationAssistantDrawer> createState() =>
      _PreparationAssistantDrawerState();
}

class _PreparationAssistantDrawerState
    extends ConsumerState<PreparationAssistantDrawer> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<AssistantTurn> _turns = <AssistantTurn>[];
  bool _loading = false;

  /// 每 turn 的期望计划版本号（accept 流程的 stale 检测基准）。生成时初始化为
  /// `changeSet.basePlanRevision`；每次成功 apply 后 bump 到新 revision。
  final Map<String, int> _expectedRevisions = <String, int>{};

  /// 每 turn 每张卡的实时状态（实体不可变，状态在 UI 层维护）。
  final Map<String, Map<String, ChangeCardStatus>> _cardStatuses =
      <String, Map<String, ChangeCardStatus>>{};

  /// 接受中的卡 id（防重 + 显示 spinner）。
  final Set<String> _applying = <String>{};

  /// 接受失败的卡 id → 错误文案（ConflictException 等）。
  final Map<String, String> _cardErrors = <String, String>{};

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final store = ref.read(assistantHistoryStoreProvider);
    final turns = await store.list(widget.planId);
    if (!mounted) return;
    setState(() {
      _turns
        ..clear()
        ..addAll(turns);
      for (final turn in turns) {
        if (turn.changeSet != null) {
          _expectedRevisions[turn.id] ??= turn.changeSet!.basePlanRevision;
          _cardStatuses[turn.id] ??= Map<String, ChangeCardStatus>.from(
            turn.cardStatuses,
          );
        }
      }
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    _input.clear();
    setState(() => _loading = true);
    final plan = widget.plan;
    final history = _turns
        .slice(_turns.length > 10 ? _turns.length - 10 : 0)
        .map(
          (t) => AssistantHistoryEntry(
            role: 'user',
            content: t.userMessage,
            cardResults: const <AssistantCardResult>[],
          ),
        )
        .toList();
    final request = PlanAssistantRequest(
      planId: widget.planId,
      calendarToday: CalendarDate.normalize(DateTime.now()),
      basePlanRevision: plan.revision,
      planSnapshot: plan,
      userMessage: text,
      history: history,
      requestId: 'req_${DateTime.now().millisecondsSinceEpoch}',
    );
    final result =
        await ref.read(preparationPlanAssistantProvider).suggestChanges(request);
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        final turn = AssistantTurn(
          id: 'turn_${DateTime.now().millisecondsSinceEpoch}',
          planId: widget.planId,
          userMessage: text,
          reply: data.reply,
          createdAt: DateTime.now().toUtc(),
          cardStatuses: {
            for (final c in data.changeSet.cards) c.id: c.status,
          },
          changeSet: data.changeSet,
        );
        await ref.read(assistantHistoryStoreProvider).append(widget.planId, turn);
        if (!mounted) return;
        setState(() {
          _turns.add(turn);
          _expectedRevisions[turn.id] = data.changeSet.basePlanRevision;
          _cardStatuses[turn.id] = {
            for (final c in data.changeSet.cards) c.id: c.status,
          };
          _loading = false;
        });
        _scrollToBottom();
      case Failure():
        final turn = AssistantTurn(
          id: 'turn_${DateTime.now().millisecondsSinceEpoch}_err',
          planId: widget.planId,
          userMessage: text,
          reply: '助手调用失败，请稍后重试。',
          createdAt: DateTime.now().toUtc(),
          cardStatuses: const {},
          error: true,
        );
        setState(() {
          _turns.add(turn);
          _loading = false;
        });
        _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// 接受一张改动卡（spec §3.6 步骤 1-8）：
  /// 1. 读最新计划；2. revision 不匹配 → 本 change set 剩余 pending 卡标 stale；
  /// 3. applyCard → 4. CAS save → 5. 成功标 applied + bump expectedRevision；
  /// 6. ConflictException 卡保持 pending + 错误；8. 已 applied 再点幂等返回。
  Future<void> _acceptCard(AssistantTurn turn, PlanChangeCard card) async {
    final statuses = _cardStatuses[turn.id];
    if (statuses == null) return;
    final current = statuses[card.id] ?? card.status;
    // 幂等：已 applied 直接返回，不重复应用。
    if (current == ChangeCardStatus.applied) return;
    // 仅 pending 可接受。
    if (current != ChangeCardStatus.pending) return;
    if (_applying.contains(card.id)) return;

    setState(() {
      _applying.add(card.id);
      _cardErrors.remove(card.id);
    });

    final repo = ref.read(preparationPlanRepositoryProvider);
    final latest = repo.findById(widget.planId);
    if (latest == null) {
      setState(() {
        _applying.remove(card.id);
        _cardErrors[card.id] = '计划不存在';
      });
      return;
    }
    final expectedRevision = _expectedRevisions[turn.id] ?? turn.changeSet!.basePlanRevision;

    // Stale 检测：最新计划 revision 与期望不一致 → 本 change set 剩余 pending
    // 全部标 stale（不应用任何卡）。
    if (latest.revision != expectedRevision) {
      setState(() {
        _cascadeStale(turn, statuses);
        _applying.remove(card.id);
      });
      await _persistStatuses(turn, statuses);
      return;
    }

    final result = PlanChangeApplier.applyCard(
      plan: latest,
      card: card,
      expectedRevision: expectedRevision,
    );

    if (result.stale) {
      setState(() {
        _cascadeStale(turn, statuses);
        _applying.remove(card.id);
      });
      await _persistStatuses(turn, statuses);
      return;
    }
    if (!result.applied) {
      setState(() {
        _cardErrors[card.id] = result.error ?? '应用失败';
        _applying.remove(card.id);
      });
      await _persistStatuses(turn, statuses);
      return;
    }

    // CAS save：newPlan 携当前 revision，仓库校验通过后 revision+1。
    try {
      final saved = await repo.save(result.newPlan!);
      if (!mounted) return;
      setState(() {
        statuses[card.id] = ChangeCardStatus.applied;
        _expectedRevisions[turn.id] = saved.revision;
        _applying.remove(card.id);
      });
      await _persistStatuses(turn, statuses);
    } on ConflictException {
      if (!mounted) return;
      setState(() {
        // 卡保持 pending，仅显示错误，不动 UI 计划快照。
        _cardErrors[card.id] = '数据已变化，请刷新后重试';
        _applying.remove(card.id);
      });
    }
  }

  /// 把本 change set 剩余 pending 卡全部标 stale。
  void _cascadeStale(AssistantTurn turn, Map<String, ChangeCardStatus> statuses) {
    for (final c in turn.changeSet!.cards) {
      final s = statuses[c.id] ?? c.status;
      if (s == ChangeCardStatus.pending) {
        statuses[c.id] = ChangeCardStatus.stale;
      }
    }
  }

  /// 拒绝一张改动卡：标 declined（折叠），不读计划不应用。
  Future<void> _declineCard(AssistantTurn turn, PlanChangeCard card) async {
    final statuses = _cardStatuses[turn.id];
    if (statuses == null) return;
    final current = statuses[card.id] ?? card.status;
    // declined 可撤销（恢复 pending）；pending 可拒绝。
    if (current != ChangeCardStatus.pending &&
        current != ChangeCardStatus.declined) {
      return;
    }
    setState(() {
      statuses[card.id] = current == ChangeCardStatus.declined
          ? ChangeCardStatus.pending
          : ChangeCardStatus.declined;
    });
    await _persistStatuses(turn, statuses);
  }

  Future<void> _persistStatuses(
    AssistantTurn turn,
    Map<String, ChangeCardStatus> statuses,
  ) async {
    await ref
        .read(assistantHistoryStoreProvider)
        .updateCardStatuses(widget.planId, turn.id, statuses);
  }

  bool get _canSubmit => _input.text.trim().isNotEmpty && !_loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(title: widget.plan.competition.name),
            Expanded(child: _buildConversation()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    final messages = <Widget>[];
    for (final turn in _turns) {
      final pair = AssistantTurnMessageMapper.toMessages(turn, widget.planId);
      messages.add(
        Padding(
          key: ValueKey('${turn.id}_user'),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ChatMessageBubble(
            message: pair[0],
            onTapRecommendation: (_) {},
          ),
        ),
      );
      messages.add(
        Padding(
          key: ValueKey('${turn.id}_assistant'),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ChatMessageBubble(
            message: pair[1],
            onTapRecommendation: (_) {},
          ),
        ),
      );
      if (!turn.error && turn.changeSet != null) {
        messages.add(
          _ChangeCardRow(
            key: ValueKey('${turn.id}_cards'),
            turn: turn,
            cards: turn.changeSet!.cards,
            statuses: _cardStatuses[turn.id] ?? const {},
            applying: _applying,
            errors: _cardErrors,
            onAccept: (card) => _acceptCard(turn, card),
            onDecline: (card) => _declineCard(turn, card),
          ),
        );
      }
    }
    if (_loading) {
      messages.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (messages.isEmpty) {
      messages.add(_buildEmptyHint());
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: messages,
    );
  }

  Widget _buildEmptyHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, size: 36, color: AppColors.indigo),
          const SizedBox(height: 12),
          Text(
            '告诉助手你想怎么调整计划',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: !_loading,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: '输入你的调整需求…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _canSubmit ? AppColors.indigo : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _canSubmit ? _send : null,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_upward,
                  color: _canSubmit ? Colors.white : AppColors.inkSoft,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 20, color: AppColors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 助手',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _ChangeCardRow extends StatelessWidget {
  const _ChangeCardRow({
    super.key,
    required this.turn,
    required this.cards,
    required this.statuses,
    required this.applying,
    required this.errors,
    required this.onAccept,
    required this.onDecline,
  });

  final AssistantTurn turn;
  final List<PlanChangeCard> cards;
  final Map<String, ChangeCardStatus> statuses;
  final Set<String> applying;
  final Map<String, String> errors;
  final ValueChanged<PlanChangeCard> onAccept;
  final ValueChanged<PlanChangeCard> onDecline;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final card = cards[i];
          return PlanChangeCardView(
            key: ValueKey('${turn.id}_${card.id}'),
            card: card,
            status: statuses[card.id] ?? card.status,
            errorMessage: errors[card.id],
            applying: applying.contains(card.id),
            onAccept: () => onAccept(card),
            onDecline: () => onDecline(card),
          );
        },
      ),
    );
  }
}

extension _ListSlice<T> on List<T> {
  List<T> slice(int start) => start <= 0 ? List<T>.of(this) : sublist(start);
}
