import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/deepseek_llm_client.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/ai/llm_trace.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';

class _StubLlm implements LlmClient {
  _StubLlm(this._result);

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
  }) => const Stream.empty();
}

void main() {
  test('complete 成功 → 记录 model/messages/raw', () async {
    LlmTrace? captured;
    final client = TracingLlmClient(
      delegate: _StubLlm(const Success('原始返回')),
      model: 'deepseek-chat',
      onTrace: (t) => captured = t,
    );
    final res = await client.complete(
      messages: const [LlmMessage('user', '你好')],
      jsonMode: true,
    );
    expect((res as Success).data, '原始返回');
    expect(captured, isNotNull);
    expect(captured!.model, 'deepseek-chat');
    expect(captured!.rawResponse, '原始返回');
    expect(captured!.messages.single.content, '你好');
    expect(captured!.elapsedMs, greaterThanOrEqualTo(0));
  });

  test('complete 失败 → 不记录', () async {
    LlmTrace? captured;
    final client = TracingLlmClient(
      delegate: _StubLlm(const Failure(ServerException())),
      model: 'm',
      onTrace: (t) => captured = t,
    );
    await client.complete(messages: const [LlmMessage('user', 'x')]);
    expect(captured, isNull);
  });

  test('llmClientProvider：演示模式关 → DeepSeekLlmClient', () {
    final c = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(llmClientProvider), isA<DeepSeekLlmClient>());
  });

  test('llmClientProvider：演示模式开 → TracingLlmClient', () {
    final c = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          const AppConfig(
            dataSource: DataSource.llm,
            featureFlags: FeatureFlags(showAiTrace: true),
            llm: LlmConfig(apiKey: 'sk-test'),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(llmClientProvider), isA<TracingLlmClient>());
  });
}
