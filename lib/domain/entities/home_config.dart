import 'home_prompt.dart';

class HomeConfig {
  const HomeConfig({
    required this.taglines,
    required this.quickTags,
    required this.prompts,
  });

  final List<String> taglines;
  final List<String> quickTags;
  final List<HomePrompt> prompts;

  static const empty = HomeConfig(taglines: [], quickTags: [], prompts: []);
}
