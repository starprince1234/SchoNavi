import '../error/app_exception.dart';
import '../result/result.dart';
import 'llm_client.dart';

class MissingLlmClient implements LlmClient {
  const MissingLlmClient();

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    return const Failure(MissingLlmConfigurationException());
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) async* {
    throw const MissingLlmConfigurationException();
  }
}
