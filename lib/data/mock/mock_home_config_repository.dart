import '../../domain/entities/home_config.dart';
import '../../domain/repositories/home_config_repository.dart';
import 'mock_home_prompt_repository.dart';

class MockHomeConfigRepository implements HomeConfigRepository {
  const MockHomeConfigRepository();

  static const Map<String, ({List<String> taglines, List<String> quickTags})>
      _configs = {
    'mentor': (
      taglines: [
        '说说你想研究的方向，我帮你找到合适的导师',
        '想做哪个方向的研究？我来帮你找导师',
        '不知道选谁？告诉我你的兴趣就好',
        '地区、方向、阶段，想到什么都可以说',
      ],
      quickTags: [
        '计算机视觉',
        '自然语言处理',
        '机器人',
        '北京',
        '上海',
        '江浙沪',
        '博士申请',
        '硕士申请',
        '人工智能',
        '推荐系统',
      ],
    ),
    'competition': (
      taglines: [
        '说说你的兴趣，我帮你找到适合的竞赛',
        '想参加什么样的比赛？我来帮你找',
        '还在纠结报哪个？告诉我你擅长什么',
        '时间、方向、组队，想到什么都可以说',
      ],
      quickTags: [
        '人工智能竞赛',
        '算法竞赛',
        '数学建模',
        '创新创业',
        '挑战杯',
        '互联网+',
        '电子设计',
        '信息安全',
        '智能车',
        '蓝桥杯',
        '团队赛',
        '个人赛',
        '近期可报名',
      ],
    ),
  };

  @override
  Future<HomeConfig> fetchConfig(String mode) async {
    final config = _configs[mode];
    final prompts = await const MockHomePromptRepository().fetchPrompts(mode);
    if (config == null) {
      return HomeConfig(taglines: const [], quickTags: const [], prompts: prompts);
    }
    return HomeConfig(
      taglines: config.taglines,
      quickTags: config.quickTags,
      prompts: prompts,
    );
  }
}
