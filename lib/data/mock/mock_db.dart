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
    '大语言模型': '大语言模型',
    '大模型安全': '大模型安全',
    '医学影像': '医学影像',
    '机器人': '机器人',
    '具身智能': '具身智能',
    'SLAM': 'SLAM',
    '机器学习': '机器学习',
    '机器学习系统': '机器学习系统',
    '图神经网络': '图神经网络',
    '计算机图形学': '计算机图形学',
    '虚拟现实': '虚拟现实',
    '软件工程': '软件工程',
    '软件测试': '软件测试',
    '形式化方法': '形式化方法',
    '网络安全': '网络安全',
    '信息安全': '信息安全',
    '数据安全': '数据安全',
    '智能制造': '智能制造',
    '数字孪生': '数字孪生',
    '机器视觉': '机器视觉',
    '模式识别': '模式识别',
    '信号处理': '信号处理',
    '集成电路': '集成电路',
    '嵌入式系统': '嵌入式系统',
    '区块链': '区块链',
    '智能计算': '智能计算',
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
    '四川',
    '成都',
    '西南',
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
    _Fixture(
      professor: const Professor(
        id: 'p_013',
        name: '牛建伟',
        university: '北京航空航天大学',
        college: '计算机学院',
        title: '教授',
        researchFields: ['具身智能', '机器人', '机器学习', '嵌入式系统'],
        bio: '北航蓝天杰出二级教授、博士生导师，IEEE Fellow，任北航具身智能机器人研究院副院长。主要从事具身智能、机器人操作系统、机器学习与智能嵌入式系统研究，主持多项国家重点研发计划和自然科学基金项目，相关工业机器人操作系统成果已在企业应用。',
        homepageUrl: 'https://scse.buaa.edu.cn/info/1078/2664.htm',
        sourceUrl: 'https://scse.buaa.edu.cn/info/1078/2664.htm',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.94,
      ),
      locationTags: ['北京'],
      limitations: ['招生信息以学校主页最新说明为准'],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_014',
        name: '邱望洁',
        university: '北京航空航天大学',
        college: '人工智能学院',
        title: '副教授',
        researchFields: ['信息安全', '区块链', '隐私计算', '网络安全'],
        bio: '北航人工智能研究院未来区块链与隐私计算高精尖创新中心副研究员、博士生导师。研究信息安全、区块链、隐私计算及交叉应用，发表多篇高水平论文并申请多项发明专利，参与长安链、雄安链等区块链系统研发与应用。',
        homepageUrl: 'https://iai.buaa.edu.cn/info/1013/2685.htm',
        sourceUrl: 'https://iai.buaa.edu.cn/info/1013/2685.htm',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.91,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_015',
        name: '白跃彬',
        university: '北京航空航天大学',
        college: '计算机学院',
        title: '教授',
        researchFields: ['智能计算', '嵌入式系统', '大模型', '云计算'],
        bio: '北航计算机学院教授、博士生导师，长期带领分布式系统与网络研究组开展智能计算系统、云操作系统性能优化、实时嵌入式操作系统等研究。主持完成多项国家自然科学基金、863 和预研项目，近期关注 AI 加速器结构及大模型训推相关智能计算系统。',
        homepageUrl: 'https://scse.buaa.edu.cn/info/1078/2662.htm',
        sourceUrl: 'https://scse.buaa.edu.cn/info/1078/2662.htm',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.9,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_016',
        name: '郎波',
        university: '北京航空航天大学',
        college: '计算机学院',
        title: '教授',
        researchFields: ['机器学习', '信息安全', '深度学习', '图神经网络'],
        bio: '北航计算机学院教授、博士生导师，研究基于机器学习的大数据分析与管理、信息安全、可解释深度学习和图神经网络。主持多项自然科学基金、863 计划和重大专项课题，在 CVPR、AAAI 等会议及 SCI 期刊发表多篇论文。',
        homepageUrl: 'https://scse.buaa.edu.cn/info/1078/2660.htm',
        sourceUrl: 'https://scse.buaa.edu.cn/info/1078/2660.htm',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.9,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_017',
        name: '汪淼',
        university: '北京航空航天大学',
        college: '计算机学院',
        title: '教授',
        researchFields: ['计算机图形学', '虚拟现实', '多模态'],
        bio: '北航计算机学院教授、博士生导师，国家级青年人才，依托虚拟现实技术与系统全国重点实验室开展计算机图形学、虚拟现实和增强现实研究。主持国家自然科学基金和校企合作项目，在 ACM TOG、IEEE TVCG、IEEE VR 等期刊会议发表论文。',
        homepageUrl: 'http://miaowang.me',
        sourceUrl: 'https://scse.buaa.edu.cn/info/1078/11962.htm',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.92,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_018',
        name: '张辉',
        university: '北京航空航天大学',
        college: '计算机学院',
        title: '教授',
        researchFields: ['网络安全', '数据安全', '人工智能', '计算机网络'],
        bio: '北航计算机学院教授、博士生导师，主讲计算机网络课程，研究计算机网络、数据安全和基于 AI 的网络安全。牵头承担国家 973、863、重点研发计划等项目，参与多项数据汇聚、管理、质量和服务相关国家标准工作。',
        homepageUrl: 'https://scse.buaa.edu.cn/info/1078/2677.htm',
        sourceUrl: 'https://scse.buaa.edu.cn/info/1078/2677.htm',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.88,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_019',
        name: '王莉莉',
        university: '北京航空航天大学',
        college: '计算机学院',
        title: '教授',
        researchFields: ['虚拟现实', '计算机图形学', '多模态'],
        bio: '北航计算机学院教授、博士生导师，虚拟现实技术与系统全国重点实验室副主任，中国计算机学会虚拟现实与可视化专委会副主任。研究虚拟现实、混合现实和计算机图形学，主持自然科学基金重大项目课题和重点研发计划课题。',
        homepageUrl: 'https://scse.buaa.edu.cn/info/1078/2672.htm',
        sourceUrl: 'https://scse.buaa.edu.cn/info/1078/2672.htm',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.9,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_020',
        name: '刘庆杰',
        university: '北京航空航天大学',
        college: '计算机学院',
        title: '教授',
        researchFields: ['计算机视觉', '多模态', '大语言模型', '深度学习'],
        bio: '北航计算机学院教授、博士生导师，主要研究计算机视觉、目标检测、视频跟踪与多模态大模型。曾获图象图形学会技术发明一等奖，指导团队在 ICDAR、ICCV VOT 等竞赛中取得成绩，在 NeurIPS、CVPR、ICML、ICCV 等会议发表论文。',
        homepageUrl: 'https://scse.buaa.edu.cn/info/1078/11957.htm',
        sourceUrl: 'https://scse.buaa.edu.cn/info/1078/11957.htm',
        updatedAt: '2026-06-05',
        dataQualityScore: 0.91,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_021',
        name: '杨海龙',
        university: '北京航空航天大学',
        college: '计算机学院',
        title: '教授',
        researchFields: ['深度学习', '大模型', '高性能计算', '智能计算'],
        bio: '北航计算机学院教授、博士生导师，研究深度学习编译优化、大模型训推系统、高性能计算和稀疏数值算法。主持国家重点研发计划和国家自然科学基金项目，在 SC、ISCA、ASPLOS、PLDI、ICSE 等会议期刊发表论文并指导超算竞赛团队。',
        homepageUrl: 'https://thomas-yang.github.io',
        sourceUrl: 'https://scse.buaa.edu.cn/info/1546/10606.htm',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.91,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_022',
        name: '潘海侠',
        university: '北京航空航天大学',
        college: '软件学院',
        title: '教授',
        researchFields: ['人工智能', '大语言模型', '计算机视觉', '具身智能', '软件工程'],
        bio: '北航软件学院教授、硕士生导师，研究人工智能与模式识别、多模态大模型、计算机视觉、具身智能、大数据技术和智能软件工程。关注多模态信息融合、云边端协同智能系统、医学影像三维重建、智慧交通、工业智检和智能制造。',
        homepageUrl:
            'https://soft.buaa.edu.cn/teachershouw.jsp?urltype=news.NewsContentUrl&wbtreeid=1224&wbnewsid=11197',
        sourceUrl:
            'https://soft.buaa.edu.cn/teachershouw.jsp?urltype=news.NewsContentUrl&wbtreeid=1224&wbnewsid=11197',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.88,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_023',
        name: '陶飞',
        university: '北京航空航天大学',
        college: '软件学院',
        title: '教授',
        researchFields: ['数字孪生', '智能制造', '云计算', '大数据'],
        bio: '北航软件学院教授、博士生导师，长期从事数字孪生、数字工程、智能制造和制造工业软件研究。主持和参与智能制造相关重点研发工作，出版多部专著，在 Nature 等期刊发表多篇高被引论文，带领团队获得国家科技进步二等奖等成果。',
        homepageUrl:
            'https://soft.buaa.edu.cn/teachershouw.jsp?urltype=news.NewsContentUrl&wbtreeid=1337&wbnewsid=12053',
        sourceUrl:
            'https://soft.buaa.edu.cn/teachershouw.jsp?urltype=news.NewsContentUrl&wbtreeid=1337&wbnewsid=12053',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.89,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_024',
        name: '伍前红',
        university: '北京航空航天大学',
        college: '网络空间安全学院',
        title: '教授',
        researchFields: ['人工智能', '网络安全', '数据安全', '隐私计算', '区块链'],
        bio: '北航网络空间安全学院教授、硕士生导师，研究去中心化人工智能、应用密码学、分布式系统安全、数据安全与隐私、区块链和数字货币。公开主页显示其长期从事密码学、信息安全、隐私保护及 AI 安全方向研究。',
        homepageUrl: 'https://cst.buaa.edu.cn/info/1111/2774.htm',
        sourceUrl: 'https://cst.buaa.edu.cn/info/1111/2774.htm',
        updatedAt: '2026-06-04',
        dataQualityScore: 0.84,
      ),
      locationTags: ['北京'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_025',
        name: '钮鑫涛',
        university: '南京大学',
        college: '智能软件与工程学院',
        title: '助理教授',
        researchFields: ['软件测试', '软件工程', '机器学习', '智能计算'],
        bio: '南京大学智能软件与工程学院助理教授、博士生导师，研究软件测试、故障定位、软件分析和基础软件测试与分析。长期关注组合测试故障定位理论与方法，在 TSE、TOSEM、ICSE、FSE、ICST 等软件工程期刊会议发表论文，成果已在企业应用。',
        homepageUrl: 'https://niuxintao.github.io',
        sourceUrl: 'https://ise.nju.edu.cn/info/1007/2491.htm',
        updatedAt: '2026-06-05',
        dataQualityScore: 0.88,
      ),
      locationTags: ['江苏', '南京', '江浙沪', '华东'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_026',
        name: '李宣东',
        university: '南京大学',
        college: '智能软件与工程学院',
        title: '教授',
        researchFields: ['软件工程', '形式化方法', '可信软件'],
        bio: '南京大学智能软件与工程学院教授、博士生导师，教学与科研工作涉及软件工程、可信软件和形式化方法。曾任南京大学计算机科学与技术系系主任、软件学院院长，兼任中国计算机学会软件工程专业委员会主任等职务。',
        homepageUrl: 'http://cs.nju.edu.cn/lixuandong',
        sourceUrl: 'http://cs.nju.edu.cn/lixuandong',
        updatedAt: '2026-06-05',
        dataQualityScore: 0.86,
      ),
      locationTags: ['江苏', '南京', '江浙沪', '华东'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_027',
        name: '孟晴开',
        university: '南京大学',
        college: '智能软件与工程学院',
        title: '助理教授',
        researchFields: ['机器学习系统', '机器学习', '计算机网络'],
        bio: '南京大学智能软件与工程学院助理教授、博士生导师，研究数据中心网络、网络传输协议和机器学习系统。以第一或通讯作者在 USENIX NSDI、IEEE INFOCOM、IEEE/ACM TON 等会议期刊发表论文，多次担任国际会议程序委员会成员。',
        homepageUrl: 'https://mengqingkai.github.io',
        sourceUrl: 'https://ise.nju.edu.cn/info/1451/2191.htm',
        updatedAt: '2026-06-05',
        dataQualityScore: 0.87,
      ),
      locationTags: ['江苏', '南京', '江浙沪', '华东'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_028',
        name: '蒋智威',
        university: '南京大学',
        college: '智能软件与工程学院',
        title: '助理教授',
        researchFields: ['自然语言处理', '深度学习', '大语言模型', '多模态'],
        bio: '南京大学智能软件与工程学院助理教授、博士生导师，研究自然语言处理和深度学习，包括大语言模型、文本表示学习、文本质量评估、情感分析、多模态处理和软工文本挖掘。近年来在 ACL、NeurIPS、ICLR、SIGIR、WWW 等会议发表论文。',
        homepageUrl: 'https://zhiweinju.github.io',
        sourceUrl: 'https://ise.nju.edu.cn/info/1007/2561.htm',
        updatedAt: '2026-06-05',
        dataQualityScore: 0.9,
      ),
      locationTags: ['江苏', '南京', '江浙沪', '华东'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_029',
        name: '姜浩',
        university: '南京大学',
        college: '能源与资源学院',
        title: '副教授',
        researchFields: ['材料计算', '人工智能', '能源应用'],
        bio: '南京大学能源与资源学院准聘副教授、博士生导师，关注物质架构原理，利用图论和人工智能等前沿技术开展材料的大规模设计、精准构筑与能源应用研究。曾在海外高校和研究机构完成博士、博士后及研究科学家训练。',
        homepageUrl: 'https://sser.nju.edu.cn/info/1003/3991.htm',
        sourceUrl: 'https://sser.nju.edu.cn/info/1003/3991.htm',
        updatedAt: '2026-06-05',
        dataQualityScore: 0.82,
      ),
      locationTags: ['江苏', '南京', '江浙沪', '华东'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_030',
        name: '肖艺能',
        university: '南京大学',
        college: '法学院',
        title: '助理教授',
        researchFields: ['人工智能', '科技治理', '知识产权'],
        bio: '南京大学法学院助理教授，研究数字经济、知识产权、科技治理、技术成果转化和人工智能监管。曾在北京大学相关研究机构从事信息技术、健康人文与人工智能法方向研究工作，兼任中国科学技术法学会人工智能法专业委员会相关职务。',
        homepageUrl: 'https://law.nju.edu.cn/info/1711/11231.htm',
        sourceUrl: 'https://law.nju.edu.cn/info/1711/11231.htm',
        updatedAt: '2026-06-05',
        dataQualityScore: 0.8,
      ),
      locationTags: ['江苏', '南京', '江浙沪', '华东'],
      limitations: ['招生偏好未在公开数据中明确'],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_031',
        name: '罗萍',
        university: '电子科技大学',
        college: '集成电路科学与工程学院（示范性微电子学院）',
        title: '教授',
        researchFields: ['集成电路', '智能计算', '低功耗设计'],
        bio: '电子科技大学教授、博士生导师，长期从事智能功率集成电路与系统、高效电源管理、模拟集成电路抗辐射加固、能量采集和低功耗数模混合集成技术研究。主持国家重大专项、自然科学基金等项目，发表论文并授权多项发明专利。',
        homepageUrl: 'https://icse.uestc.edu.cn/info/1812/6530.htm',
        sourceUrl: 'https://icse.uestc.edu.cn/info/1812/6530.htm',
        updatedAt: '2026-06-06',
        dataQualityScore: 0.89,
      ),
      locationTags: ['四川', '成都', '西南'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_032',
        name: '姜晶',
        university: '电子科技大学',
        college: '集成电路科学与工程学院（示范性微电子学院）',
        title: '教授',
        researchFields: ['材料计算', '集成电路', '智能传感'],
        bio: '电子科技大学集成电路科学与工程学院教授、博士生导师，研究复杂环境下在线测量方法与仪器、高温高动态测量、热电制冷材料及元器件。主持国家自然科学基金面上项目、国家测试仪器工程产品替代研制项目等多项课题。',
        homepageUrl: 'https://icse.uestc.edu.cn/info/1812/6516.htm',
        sourceUrl: 'https://icse.uestc.edu.cn/info/1812/6516.htm',
        updatedAt: '2026-06-06',
        dataQualityScore: 0.87,
      ),
      locationTags: ['四川', '成都', '西南'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_033',
        name: '高艳',
        university: '电子科技大学',
        college: '自动化工程学院',
        title: '副研究员',
        researchFields: ['机器学习', '模式识别', '智能控制', '故障诊断'],
        bio: '电子科技大学自动化工程学院副研究员，研究新能源系统及控制技术、系统工程与智能装备、故障诊断与健康管理、模式识别与机器学习。主持四川省科技支撑计划和中科院西部之光项目，关注燃料电池智能化算法与寿命预测。',
        homepageUrl: 'https://www.auto.uestc.edu.cn/info/1097/4520.htm',
        sourceUrl: 'https://www.auto.uestc.edu.cn/info/1097/4520.htm',
        updatedAt: '2026-06-06',
        dataQualityScore: 0.86,
      ),
      locationTags: ['四川', '成都', '西南'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_034',
        name: '何茜',
        university: '电子科技大学',
        college: '信息与通信工程学院',
        title: '教授',
        researchFields: ['信号处理', '人工智能', '医学影像', '雷达'],
        bio: '电子科技大学信息与通信工程学院教授、博士生导师，研究统计信号处理、数字信号处理、人工智能及其在雷达、通信和医学中的应用。曾任 IEEE 信号处理学会相关专委会和期刊编委，获得 IET 国际雷达会议最佳论文等奖项。',
        homepageUrl: 'https://www.sice.uestc.edu.cn/info/1450/11705.htm',
        sourceUrl: 'https://www.sice.uestc.edu.cn/info/1450/11705.htm',
        updatedAt: '2026-06-06',
        dataQualityScore: 0.88,
      ),
      locationTags: ['四川', '成都', '西南'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_035',
        name: '张凤荔',
        university: '电子科技大学',
        college: '信息与软件工程学院（示范性软件学院）',
        title: '教授',
        researchFields: ['软件工程', '网络安全', '云计算', '大数据', '智能计算'],
        bio: '电子科技大学信息与软件工程学院教授、博士生导师，研究软件理论、网络安全与网络工程、云计算与大数据、智能计算。长期从事计算机教学与科研，参与和主持多项国家重点科技攻关、863、省部级和网络安全相关项目。',
        homepageUrl: 'https://sise.uestc.edu.cn/info/1035/5658.htm',
        sourceUrl: 'https://sise.uestc.edu.cn/info/1035/5658.htm',
        updatedAt: '2026-06-06',
        dataQualityScore: 0.87,
      ),
      locationTags: ['四川', '成都', '西南'],
      limitations: const [],
    ),
    _Fixture(
      professor: const Professor(
        id: 'p_036',
        name: '邵晋梁',
        university: '电子科技大学',
        college: '自动化工程学院',
        title: '教授',
        researchFields: ['群体智能', '机器视觉', '智能控制', '机器人'],
        bio: '电子科技大学自动化工程学院教授、博士生导师，长期从事群体智能机理、多智能体系统协同控制、无人集群系统智能感知与协同定位研究。发表学术论文百余篇，授权发明专利多项，主持国家自然科学基金等项目。',
        homepageUrl: 'https://www.auto.uestc.edu.cn/info/1168/4337.htm',
        sourceUrl: 'https://www.auto.uestc.edu.cn/info/1168/4337.htm',
        updatedAt: '2026-06-06',
        dataQualityScore: 0.86,
      ),
      locationTags: ['四川', '成都', '西南'],
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
