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
}
