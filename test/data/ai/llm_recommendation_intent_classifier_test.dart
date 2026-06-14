import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/llm_recommendation_intent_classifier.dart';
import 'package:scho_navi/shared/utils/recommendation_intent_router.dart';

class _FakeLlm implements LlmClient {
  const _FakeLlm(this._result);

  final Result<String> _result;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async => _result;

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
}

void main() {
  test('classifies mentor intent from LLM output', () async {
    final classifier = LlmRecommendationIntentClassifier(
      _FakeLlm(const Success('{"intent":"mentor"}')),
    );

    final intent = await classifier.classify('我想找计算机视觉方向导师');

    expect(intent, RecommendationIntent.mentor);
  });

  test('classifies competition intent from LLM output', () async {
    final classifier = LlmRecommendationIntentClassifier(
      _FakeLlm(const Success('{"intent":"competition"}')),
    );

    final intent = await classifier.classify('推荐几个适合我的竞赛');

    expect(intent, RecommendationIntent.competition);
  });

  test('passes through LLM failures', () async {
    final classifier = LlmRecommendationIntentClassifier(
      _FakeLlm(const Failure(NetworkException())),
    );

    expect(classifier.classify('x'), throwsA(isA<NetworkException>()));
  });

  test('malformed LLM output throws ServerException', () async {
    final classifier = LlmRecommendationIntentClassifier(
      _FakeLlm(const Success('{"intent":"other"}')),
    );

    expect(classifier.classify('x'), throwsA(isA<ServerException>()));
  });
}
