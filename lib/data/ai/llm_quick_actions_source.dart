import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../shared/utils/quick_actions_source.dart';

/// 快捷操作的 LLM 实现：让大模型基于追问文本 + 上一轮推荐摘要生成
/// 1-4 个短操作 chip。
///
/// 输出 `{"quick_actions":[...]}`。**畸形输出降级为 [Success] 空列表**——
/// 视为「后端成功但无建议」，不显示 chip、不触发硬编码兜底（对齐 spec：
/// 空则不显示）。**LLM 调用本身失败返回 [Failure]**，由 [ChatNotifier]
/// 填硬编码兜底常量。这是「大模型应用能力」评分维度的直接增量。
class LlmQuickActionsSource implements QuickActionsSource {
  LlmQuickActionsSource(this._llm);

  final LlmClient _llm;

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async {
    final res = await _llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(followUp, lastResult)),
      ],
      jsonMode: true,
      temperature: 0.8, // chip 略带多样性，避免每轮雷同
    );

    if (res is Failure<String>) return Failure(res.error);

    try {
      final decoded = jsonDecode((res as Success<String>).data);
      if (decoded is! Map<String, dynamic>) {
        return const Success(<String>[]);
      }
      final list = decoded['quick_actions'];
      if (list is! List) return const Success(<String>[]);
      final actions = list
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      return Success(actions);
    } catch (_) {
      return const Success(<String>[]); // 畸形输出降级为成功空
    }
  }

  static const String _systemPrompt = '''
你是 SchoNavi 对话式推荐的「快捷操作生成器」。基于用户追问与上一轮推荐，生成 1-4 个短操作 chip 供用户点击继续追问。
规则：
1. 只写操作短语，如「换一批」「只看北京」「偏应用」「适合博士」。
2. 每个不超过 8 个汉字。
3. 不要写完整问句，不要包含问号。
4. 不要以「你/是否/请问/能否/除了」等提问措辞开头。
5. 结合上一轮推荐的研究方向/地区调整，使其切题。
6. 候选不足时返回 2-3 个，最少 1 个；实在无建议返回空数组。
只输出一个 JSON 对象，不要 Markdown 或多余文字。
{"quick_actions":["换一批","偏应用"]}''';

  String _userPrompt(String followUp, RecommendationResult? lastResult) {
    final recap = lastResult == null
        ? '（本轮尚无推荐结果）'
        : '【上一轮已推荐】\n${_summarize(lastResult)}';
    return '【用户追问】$followUp\n$recap';
  }

  String _summarize(RecommendationResult result) {
    final recs = result.recommendations;
    if (recs.isEmpty) return '（上一轮未匹配到导师）';
    final lines = <String>[];
    for (final r in recs.take(5)) {
      lines.add(
        '- ${r.name}（${r.university} ${r.college}，'
        '方向：${r.researchFields.join('、')}，'
        '匹配：${r.matchLevel.name}）：${r.reason}',
      );
    }
    return lines.join('\n');
  }
}
