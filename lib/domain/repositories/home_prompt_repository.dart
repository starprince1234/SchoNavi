import '../entities/home_prompt.dart';

/// Repository for fetching suggested prompts on the home screen.
///
/// [mode] is expected to be a stable identifier such as `'mentor'` or
/// `'competition'`.
abstract interface class HomePromptRepository {
  Future<List<HomePrompt>> fetchPrompts(String mode);
}
