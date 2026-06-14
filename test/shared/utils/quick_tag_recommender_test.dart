import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/shared/utils/quick_tag_recommender.dart';

void main() {
  group('recommendQuickTags', () {
    test('空档案返回兜底热门标签', () {
      const profile = UserProfile();
      final tags = recommendQuickTags(profile);

      expect(tags, isNotEmpty);
      expect(tags.first, '人工智能');
      expect(tags.contains('计算机视觉'), isTrue);
      expect(tags.contains('自然语言处理'), isTrue);
    });

    test('研究兴趣直接作为标签', () {
      const profile = UserProfile(researchInterests: ['深度学习', '强化学习']);
      final tags = recommendQuickTags(profile);

      expect(tags, ['深度学习', '强化学习']);
    });

    test('目标阶段包含硕士/博士时生成对应标签', () {
      const master = UserProfile(targetDegree: '申请硕士');
      expect(recommendQuickTags(master), contains('硕士申请'));

      const phd = UserProfile(targetDegree: '申请博士');
      expect(recommendQuickTags(phd), contains('博士申请'));
    });

    test('根据学校推断地区标签', () {
      expect(
        recommendQuickTags(const UserProfile(school: '清华大学')),
        contains('北京'),
      );
      expect(
        recommendQuickTags(const UserProfile(school: '复旦大学')),
        contains('上海'),
      );
      expect(
        recommendQuickTags(const UserProfile(school: '浙江大学')),
        contains('江浙沪'),
      );
      expect(
        recommendQuickTags(const UserProfile(school: '南京大学')),
        contains('江浙沪'),
      );
    });

    test('综合档案按规则顺序返回标签', () {
      const profile = UserProfile(
        researchInterests: ['计算机视觉'],
        targetDegree: '申请博士',
        school: '清华大学',
      );
      final tags = recommendQuickTags(profile);

      expect(tags, [
        '计算机视觉',
        '博士申请',
        '北京',
      ]);
    });

    test('研究兴趣重复时去重', () {
      const profile = UserProfile(
        researchInterests: ['AI', 'ai', 'AI'],
      );
      final tags = recommendQuickTags(profile);

      expect(tags.where((t) => t == 'AI'), hasLength(1));
    });

    test('研究兴趣前后空白会被 trim', () {
      const profile = UserProfile(
        researchInterests: [' AI ', 'AI'],
      );
      final tags = recommendQuickTags(profile);

      expect(tags, ['AI']);
    });

    test('major 为空时作为补充标签', () {
      const profile = UserProfile(major: '计算机科学与技术');
      final tags = recommendQuickTags(profile);

      expect(tags.first, '计算机科学与技术');
    });

    test('中国农业大学识别为北京', () {
      const profile = UserProfile(school: '中国农业大学');
      final tags = recommendQuickTags(profile);

      expect(tags, contains('北京'));
    });

    test('maxCount 可限制返回数量', () {
      const profile = UserProfile(
        researchInterests: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
      );
      final tags = recommendQuickTags(profile, maxCount: 3);

      expect(tags.length, 3);
    });
  });
}
