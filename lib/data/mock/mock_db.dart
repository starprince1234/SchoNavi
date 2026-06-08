import '../../domain/entities/match_level.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/query_understanding.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/recommendation_result.dart';

/// 内存假数据库：导师 fixtures + 简单关键词匹配，产出像真的推荐结果。
class MockDb {
  MockDb();

  /// 已知研究方向关键词；同义词归一到展示名。
  static const Map<String, String> _interestSynonyms = {
    '人工智能': '人工智能',
    'AI': '人工智能',
    '计算机视觉': '计算机视觉',
    'CV': '计算机视觉',
    '自然语言处理': '自然语言处理',
    'NLP': '自然语言处理',
    '大模型': '大模型',
    '大模型安全': '大模型安全',
    '医学影像': '医学影像',
    '机器人': '机器人',
    '具身智能': '具身智能',
    'SLAM': 'SLAM',
    '网络安全': '网络安全',
    '隐私计算': '隐私计算',
    '联邦学习': '联邦学习',
    '生物信息': '生物信息',
    '材料计算': '材料计算',
    '深度学习': '深度学习',
    '强化学习': '强化学习',
    '推荐系统': '推荐系统',
    '知识图谱': '知识图谱',
    '自动驾驶': '自动驾驶',
    '多模态': '多模态',
  };

  static const List<String> _locationKeywords = [
    '北京',
    '上海',
    '江浙沪',
    '浙江',
    '杭州',
    '江苏',
    '南京',
    '广东',
    '深圳',
    '广州',
    '安徽',
    '合肥',
    '陕西',
    '西安',
    '黑龙江',
    '哈尔滨',
    '华东',
  ];

  final List<_Fixture> _fixtures = _buildFixtures();

  List<Professor> get allProfessors =>
      _fixtures.map((f) => f.professor).toList(growable: false);

  Professor? getProfessor(String id) {
    for (final f in _fixtures) {
      if (f.professor.id == id) return f.professor;
    }
    return null;
  }

  RecommendationResult recommend(String prompt, {String? sessionId}) {
    final interests = _detectInterests(prompt);
    final locations = _detectLocations(prompt);
    final degree = _detectDegree(prompt);

    final scored = <_Scored>[];
    for (final f in _fixtures) {
      final matchedFields = f.professor.researchFields
          .where((field) => interests.contains(field))
          .toList();
      final matchedLocs = f.locationTags
          .where((loc) => locations.contains(loc))
          .toList();
      final score = matchedFields.length * 2 + matchedLocs.length;
      if (score <= 0) continue;
      scored.add(_Scored(f, score, matchedFields));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final maxScore = scored.isEmpty ? 1 : scored.first.score;
    final recommendations = scored.map((s) {
      final normScore = (s.score / (maxScore == 0 ? 1 : maxScore)).clamp(
        0.0,
        1.0,
      );
      return Recommendation(
        professorId: s.fixture.professor.id,
        name: s.fixture.professor.name,
        university: s.fixture.professor.university,
        college: s.fixture.professor.college,
        title: s.fixture.professor.title,
        researchFields: s.fixture.professor.researchFields,
        homepageUrl: s.fixture.professor.homepageUrl,
        matchLevel: _levelFor(s.score),
        matchScore: double.parse(normScore.toStringAsFixed(2)),
        reason: _buildReason(s.matchedFields, locations),
        limitations: s.fixture.limitations,
      );
    }).toList();

    return RecommendationResult(
      sessionId: sessionId ?? 's_${prompt.hashCode.toUnsigned(20)}',
      queryUnderstanding: QueryUnderstanding(
        researchInterests: interests,
        preferredLocations: locations,
        preferredUniversities: const [],
        degreeStage: degree,
        uncertainties: _buildUncertainties(prompt, degree),
      ),
      recommendations: recommendations,
      followUpQuestions: const ['你更倾向理论研究还是应用研究？', '是否只考虑 985 / 双一流 高校？'],
    );
  }

  List<String> _detectInterests(String prompt) {
    final found = <String>{};
    _interestSynonyms.forEach((kw, canonical) {
      if (prompt.contains(kw)) found.add(canonical);
    });
    return found.toList();
  }

  List<String> _detectLocations(String prompt) =>
      _locationKeywords.where(prompt.contains).toSet().toList();

  String? _detectDegree(String prompt) {
    if (prompt.contains('博士') ||
        prompt.contains('申博') ||
        prompt.contains('读博')) {
      return '博士';
    }
    if (prompt.contains('硕士') ||
        prompt.contains('保研') ||
        prompt.contains('考研') ||
        prompt.contains('读研')) {
      return '硕士';
    }
    return null;
  }

  MatchLevel _levelFor(int score) {
    if (score >= 4) return MatchLevel.high;
    if (score >= 2) return MatchLevel.medium;
    return MatchLevel.low;
  }

  String _buildReason(List<String> matchedFields, List<String> locations) {
    final fieldPart = matchedFields.isEmpty
        ? '其公开研究方向与你的需求相关'
        : '公开资料显示其研究方向涵盖${matchedFields.join('、')}，与你的需求高度相关';
    final locPart = locations.isEmpty
        ? ''
        : '；且所在地区匹配你的偏好（${locations.join('、')}）';
    return '$fieldPart$locPart。';
  }

  List<String> _buildUncertainties(String prompt, String? degree) {
    final items = <String>[];
    if (degree == null) items.add('未明确申请硕士还是博士');
    if (!prompt.contains('理论') && !prompt.contains('应用')) {
      items.add('未明确偏理论或应用');
    }
    return items;
  }

  static List<_Fixture> _buildFixtures() => [
    _Fixture(
      professor: const Professor(
        id: 'p_001',
        name: '张三',
        university: '上海交通大学',
        college: '电子信息与电气工程学院',
        title: '教授',
        researchFields: ['医学影像', '计算机视觉', '深度学习'],
        bio: '主要研究医学影像分析与深度学习在临床中的应用。',
        homepageUrl: 'https://example.edu.cn/zhangsan',
        sourceUrl: 'https://example.edu.cn/zhangsan/source',
        updatedAt: '2026-06-01',
        dataQualityScore: 0.87,
      ),
      locationTags: ['上海', '华东'],
      limitations: ['公开资料中未明确招生信息'],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_002',
        name: '李娜',
        university: '清华大学',
        college: '计算机科学与技术系',
        title: '副教授',
        researchFields: ['自然语言处理', '大模型', '知识图谱'],
        bio: '研究大模型与信息抽取。',
        homepageUrl: 'https://example.edu.cn/lina',
        updatedAt: '2026-05-20',
        dataQualityScore: 0.82,
      ),
      locationTags: ['北京'],
      limitations: ['主页链接可能变更，请以学校官网为准'],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_003',
        name: '王强',
        university: '北京大学',
        college: '信息科学技术学院',
        title: '教授',
        researchFields: ['计算机视觉', '自动驾驶', '深度学习'],
        bio: '聚焦目标检测与自动驾驶感知。',
        homepageUrl: 'https://example.edu.cn/wangqiang',
        updatedAt: '2026-04-18',
        dataQualityScore: 0.9,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_004',
        name: '刘洋',
        university: '浙江大学',
        college: '计算机科学与技术学院',
        title: '研究员',
        researchFields: ['机器人', '强化学习', 'SLAM'],
        bio: '研究机器人运动规划与强化学习。',
        homepageUrl: 'https://example.edu.cn/liuyang',
        updatedAt: '2026-05-02',
        dataQualityScore: 0.78,
      ),
      locationTags: ['浙江', '杭州', '江浙沪', '华东'],
      limitations: ['公开资料中未明确招生名额'],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_005',
        name: '陈静',
        university: '复旦大学',
        college: '大数据学院',
        title: '教授',
        researchFields: ['医学影像', '生物信息', '深度学习'],
        bio: '研究医学影像与生物信息交叉。',
        homepageUrl: 'https://example.edu.cn/chenjing',
        updatedAt: '2026-03-30',
        dataQualityScore: 0.85,
      ),
      locationTags: ['上海', '江浙沪', '华东'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_006',
        name: '赵磊',
        university: '南京大学',
        college: '人工智能学院',
        title: '副教授',
        researchFields: ['自然语言处理', '大模型安全', '多模态'],
        bio: '研究大模型对齐与安全。',
        homepageUrl: 'https://example.edu.cn/zhaolei',
        updatedAt: '2026-05-11',
        dataQualityScore: 0.8,
      ),
      locationTags: ['江苏', '南京', '江浙沪', '华东'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_007',
        name: '孙婷',
        university: '中国科学技术大学',
        college: '信息科学技术学院',
        title: '教授',
        researchFields: ['网络安全', '隐私计算', '联邦学习'],
        bio: '研究隐私计算与联邦学习。',
        updatedAt: '2026-02-15',
        dataQualityScore: 0.74,
      ),
      locationTags: ['安徽', '合肥', '华东'],
      limitations: ['暂无公开主页链接'],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_008',
        name: '周凯',
        university: '上海科技大学',
        college: '信息科学与技术学院',
        title: '副教授',
        researchFields: ['材料计算', '深度学习'],
        bio: '研究机器学习势与第一性原理计算。',
        homepageUrl: 'https://example.edu.cn/zhoukai',
        updatedAt: '2026-04-01',
        dataQualityScore: 0.76,
      ),
      locationTags: ['上海', '江浙沪', '华东'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_009',
        name: '吴敏',
        university: '哈尔滨工业大学',
        college: '计算学部',
        title: '教授',
        researchFields: ['自然语言处理', '多模态', '机器翻译'],
        bio: '研究机器翻译与多模态理解。',
        homepageUrl: 'https://example.edu.cn/wumin',
        updatedAt: '2026-01-20',
        dataQualityScore: 0.79,
      ),
      locationTags: ['黑龙江', '哈尔滨'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_010',
        name: '郑昊',
        university: '中山大学',
        college: '计算机学院',
        title: '研究员',
        researchFields: ['计算机视觉', '医学影像'],
        bio: '研究弱监督医学影像分析。',
        homepageUrl: 'https://example.edu.cn/zhenghao',
        updatedAt: '2026-05-25',
        dataQualityScore: 0.81,
      ),
      locationTags: ['广东', '广州'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_011',
        name: '冯雪',
        university: '同济大学',
        college: '电子与信息工程学院',
        title: '副教授',
        researchFields: ['机器人', '具身智能', 'SLAM'],
        bio: '研究具身智能与机器人感知。',
        homepageUrl: 'https://example.edu.cn/fengxue',
        updatedAt: '2026-04-22',
        dataQualityScore: 0.77,
      ),
      locationTags: ['上海', '江浙沪', '华东'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_012',
        name: '许诺',
        university: '西安交通大学',
        college: '人工智能学院',
        title: '教授',
        researchFields: ['大模型', '推荐系统', '知识图谱'],
        homepageUrl: 'https://example.edu.cn/xunuo',
        updatedAt: '2026-03-10',
        dataQualityScore: 0.83,
      ),
      locationTags: ['陕西', '西安'],
      limitations: const [],
    ),
  ];
}

class _Fixture {
  const _Fixture({
    required this.professor,
    required this.locationTags,
    required this.limitations,
  });

  final Professor professor;
  final List<String> locationTags;
  final List<String> limitations;
}

class _Scored {
  const _Scored(this.fixture, this.score, this.matchedFields);

  final _Fixture fixture;
  final int score;
  final List<String> matchedFields;
}
