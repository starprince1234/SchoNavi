import '../../domain/entities/home_prompt.dart';
import '../../domain/repositories/home_prompt_repository.dart';

/// Mock implementation of [HomePromptRepository].
///
/// Returns a fixed set of 4 prompts per mode so the home bento grid renders a
/// symmetric 2x2 layout. Replace with [HttpHomePromptRepository] once the
/// backend endpoint is ready.
class MockHomePromptRepository implements HomePromptRepository {
  const MockHomePromptRepository();

  static const Map<String, List<HomePrompt>> _prompts = {
    'mentor': [
      HomePrompt(text: '我想找计算机视觉方向的导师，最好在北京。'),
      HomePrompt(text: '我想做 AI 和医疗结合的研究，有没有适合的老师？'),
      HomePrompt(text: '推荐几个 NLP 和大模型安全方向的导师。'),
      HomePrompt(text: '我是自动化背景，想申请机器人方向博士。'),
    ],
    'competition': [
      HomePrompt(text: '推荐近期可报名的人工智能竞赛。'),
      HomePrompt(text: '适合计算机专业大一参加的团队赛。'),
      HomePrompt(text: '我想参加数学建模竞赛，有什么建议？'),
      HomePrompt(text: '帮我找算法竞赛，最好有校内选拔。'),
    ],
  };

  @override
  Future<List<HomePrompt>> fetchPrompts(String mode) async {
    // Simulate a short network round-trip so the loading state is realistic.
    await Future.delayed(const Duration(milliseconds: 200));
    return _prompts[mode] ?? const [];
  }
}
