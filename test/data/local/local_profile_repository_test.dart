import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';
import 'package:scho_navi/data/local/local_profile_repository.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';
import 'package:scho_navi/domain/entities/competition.dart';
import 'package:scho_navi/domain/entities/research_item.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

void main() {
  late LocalProfileRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    repo = LocalProfileRepository(SharedPreferencesLocalStore(prefs));
  });

  test('未保存时 load 返回空 profile', () {
    expect(repo.load().isEmpty, isTrue);
  });

  test('save 后 load 往返', () async {
    await repo.save(
      const UserProfile(
        name: '张三',
        degreeStage: '本科在读',
        school: '上海交通大学',
        major: '计算机科学与技术',
        researchInterests: ['人工智能', '计算机视觉'],
        highlights: 'GPA 3.9/4.0，一篇在投论文',
      ),
    );

    final profile = repo.load();
    expect(profile.name, '张三');
    expect(profile.degreeStage, '本科在读');
    expect(profile.school, '上海交通大学');
    expect(profile.major, '计算机科学与技术');
    expect(profile.researchInterests, ['人工智能', '计算机视觉']);
    expect(profile.highlights, 'GPA 3.9/4.0，一篇在投论文');
  });

  test('空字段不写入，load 仍可解析', () async {
    await repo.save(const UserProfile(name: '李四'));

    final profile = repo.load();
    expect(profile.name, '李四');
    expect(profile.school, isNull);
    expect(profile.researchInterests, isEmpty);
  });

  test('新字段（性别/成绩/竞赛/科研）往返', () async {
    await repo.save(
      const UserProfile(
        name: '王五',
        gender: Gender.female,
        targetDegree: '申请博士',
        score: AcademicScore(gpa: 3.8, scale: 4.0, rank: '前 5%'),
        competitions: [
          Competition(name: 'ACM 区域赛', level: '国家级', award: '银牌', year: '2024'),
        ],
        research: [
          ResearchItem(
            type: ResearchType.paper,
            title: '深度学习用于医学影像',
            role: '第一作者',
            venueOrStatus: 'EI 会议 / 已发表',
            year: '2024',
          ),
        ],
      ),
    );

    final p = repo.load();
    expect(p.gender, Gender.female);
    expect(p.targetDegree, '申请博士');
    expect(p.score?.gpa, 3.8);
    expect(p.score?.scale, 4.0);
    expect(p.score?.rank, '前 5%');
    expect(p.competitions.single.award, '银牌');
    expect(p.research.single.type, ResearchType.paper);
    expect(p.research.single.role, '第一作者');
  });

  test('旧版仅含基础字段的 JSON 仍可加载（向后兼容）', () async {
    // 直接写入旧结构（无新字段）
    await prefs.setString(
      LocalProfileRepository.storageKey,
      '{"name":"老用户","school":"清华大学","research_interests":["人工智能"]}',
    );
    repo = LocalProfileRepository(SharedPreferencesLocalStore(prefs));

    final p = repo.load();
    expect(p.name, '老用户');
    expect(p.school, '清华大学');
    expect(p.researchInterests, ['人工智能']);
    expect(p.gender, isNull);
    expect(p.score, isNull);
    expect(p.competitions, isEmpty);
  });
}
