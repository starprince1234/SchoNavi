import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';
import 'package:scho_navi/data/local/local_profile_repository.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

void main() {
  late LocalProfileRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
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
}
