import '../result/result.dart';

class LlmMessage {
  const LlmMessage(this.role, this.content);

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

abstract interface class LlmClient {
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  });

  /// 流式补全：逐段 emit 文本增量（delta）。
  /// 失败时通过 Stream 抛出 AppException；完成时正常关闭。
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  });
}
