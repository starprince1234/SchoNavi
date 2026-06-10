import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../result/result.dart';
import 'llm_client.dart';

/// 最近一次大模型调用快照（仅演示模式记录，用于"AI 透明化"展示）。
class LlmTrace {
  const LlmTrace({
    required this.model,
    required this.messages,
    required this.rawResponse,
    required this.elapsedMs,
  });

  final String model;
  final List<LlmMessage> messages;
  final String rawResponse;
  final int elapsedMs;
}

/// 装饰器：包裹任意 [LlmClient]，在 complete 成功时把调用快照交给 [onTrace]。
/// 流式 [stream] 直接透传，不记录快照。默认不在生产路径启用（见 llmClientProvider）。
class TracingLlmClient implements LlmClient {
  TracingLlmClient({
    required this.delegate,
    required this.model,
    required this.onTrace,
  });

  final LlmClient delegate;
  final String model;
  final void Function(LlmTrace trace) onTrace;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    final sw = Stopwatch()..start();
    final res = await delegate.complete(
      messages: messages,
      jsonMode: jsonMode,
      temperature: temperature,
    );
    sw.stop();
    if (res is Success<String>) {
      onTrace(
        LlmTrace(
          model: model,
          messages: messages,
          rawResponse: res.data,
          elapsedMs: sw.elapsedMilliseconds,
        ),
      );
    }
    return res;
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => delegate.stream(messages: messages, temperature: temperature);
}

/// 持有最近一次 [LlmTrace]，供演示页面 watch。默认 null。
class AiTraceController extends Notifier<LlmTrace?> {
  @override
  LlmTrace? build() => null;

  void record(LlmTrace trace) => state = trace;

  void clear() => state = null;
}

final aiTraceProvider = NotifierProvider<AiTraceController, LlmTrace?>(
  AiTraceController.new,
);
