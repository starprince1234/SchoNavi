import '../../domain/entities/user_profile.dart';

/// 根据学生档案推荐首页快捷标签。
///
/// 规则优先级：
/// 1. [UserProfile.researchInterests] 直接作为候选标签。
/// 2. [UserProfile.targetDegree] 推断「硕士申请」/「博士申请」。
/// 3. [UserProfile.school] 推断地区标签（北京 / 上海 / 江浙沪）。
/// 4. 档案为空时返回兜底热门标签。
///
/// 返回结果已去重，并按规则顺序排列，最多 [maxCount] 个。
List<String> recommendQuickTags(UserProfile profile, {int maxCount = 8}) {
  assert(maxCount > 0, 'maxCount must be positive');
  final tags = <String>[];
  final seen = <String>{};

  void add(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    if (seen.add(trimmed)) tags.add(trimmed);
  }

  for (final interest in profile.researchInterests) {
    add(interest);
  }

  if (profile.major case final major?) {
    add(major);
  }

  final target = profile.targetDegree;
  if (target != null) {
    if (target.contains('硕士')) add('硕士申请');
    if (target.contains('博士')) add('博士申请');
  }

  final location = _inferLocation(profile.school);
  if (location != null) add(location);

  if (tags.isEmpty) {
    for (final tag in _fallbackTags) {
      add(tag);
    }
  }

  return tags.take(maxCount).toList();
}

String? _inferLocation(String? school) {
  if (school == null || school.isEmpty) return null;
  final normalized = school.toLowerCase();

  const beijingKeywords = [
    '清华',
    '北大',
    '人民大学',
    '北航',
    '北理',
    '北师',
    '中国农业',
    '中央民族',
    '北京',
  ];
  for (final keyword in beijingKeywords) {
    if (normalized.contains(keyword.toLowerCase())) return '北京';
  }

  const shanghaiKeywords = [
    '上海交大',
    '复旦',
    '同济',
    '华东师范',
    '上科',
    '上海',
  ];
  for (final keyword in shanghaiKeywords) {
    if (normalized.contains(keyword.toLowerCase())) return '上海';
  }

  const jiangzhehuKeywords = [
    '浙江',
    '浙大',
    '南京大学',
    '东南大学',
    '南京',
    '苏州',
    '江苏',
    '中科大',
    '中国科学技术大学',
    '合肥',
    '安徽',
  ];
  for (final keyword in jiangzhehuKeywords) {
    if (normalized.contains(keyword.toLowerCase())) return '江浙沪';
  }

  return null;
}

const _fallbackTags = [
  '人工智能',
  '计算机视觉',
  '自然语言处理',
  '医学影像',
  '机器人',
  '网络安全',
  '生物信息',
  '材料计算',
];
