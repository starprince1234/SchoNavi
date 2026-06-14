import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../shared/utils/recommendation_intent_router.dart';

class LlmRecommendationIntentClassifier
    implements RecommendationIntentClassifier {
  const LlmRecommendationIntentClassifier(this.llm);

  final LlmClient llm;

  @override
  Future<RecommendationIntent> classify(String prompt) async {
    final result = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', '【用户输入】$prompt'),
      ],
      jsonMode: true,
      temperature: 0,
    );

    if (result is Failure<String>) throw result.error;

    try {
      final decoded = jsonDecode((result as Success<String>).data);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return switch (decoded['intent']) {
        'competition' => RecommendationIntent.competition,
        'mentor' => RecommendationIntent.mentor,
        _ => throw const FormatException(),
      };
    } catch (_) {
      throw const ServerException();
    }
  }

  static const String _systemPrompt = '''
你是 SchoNavi 的入口意图分类器。判断用户当前是想找导师，还是想找大学生竞赛/比赛推荐。
只输出 JSON 对象，不要 Markdown 或多余文字。
intent 只能取 mentor 或 competition。
{"intent":"mentor"}
''';
}
