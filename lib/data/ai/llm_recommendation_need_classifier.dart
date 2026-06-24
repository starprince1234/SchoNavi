import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../shared/utils/recommendation_need_classifier.dart';

/// 用大模型判定追问是否需要新一轮推荐（产卡）。
///
/// 把追问文本 + 上一轮推荐摘要（姓名/方向/匹配理由）作为上下文喂给 LLM，
/// 让它输出 `{"need": true|false}`。这是「大模型应用能力」的直接体现——
/// 用 LLM 做对话路由，替代关键词匹配（见 spec §4.5 / §11）。
///
/// 失败 / 畸形输出一律降级返回 false：宁可少产一张卡，也不让路由错误
/// 阻断对话流。首轮无推荐结果时 [lastResult] 传 null，LLM 仅据追问文本判断。
class LlmRecommendationNeedClassifier implements RecommendationNeedClassifier {
  const LlmRecommendationNeedClassifier(this.llm);

  final LlmClient llm;

  @override
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  }) async {
    final result = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(followUp, lastResult)),
      ],
      jsonMode: true,
      temperature: 0,
    );

    if (result is Failure<String>) return false;

    try {
      final decoded = jsonDecode((result as Success<String>).data);
      if (decoded is! Map<String, dynamic>) return false;
      return decoded['need'] == true;
    } catch (_) {
      return false;
    }
  }

  static const String _systemPrompt = '''
你是 SchoNavi 对话式推荐的「追问路由器」。判断用户的追问是需要**重新/调整推荐导师**，还是**针对已有推荐的解释或咨询**。
- need=true：用户想要新的导师推荐、换一批、按地区/方向重筛、求相似导师等。
- need=false：用户在问已推荐导师的详情、研究方向、是否适合、套磁方法等，不需要新一轮推荐。
只输出一个 JSON 对象，不要 Markdown 或多余文字。
{"need":true}
''';

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
