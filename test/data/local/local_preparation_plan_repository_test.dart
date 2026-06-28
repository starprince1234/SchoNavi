import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';
import 'package:scho_navi/data/local/local_preparation_plan_repository.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

PreparationPlan _plan({required String id, required String compId, PreparationPlanStatus status = PreparationPlanStatus.active}) =>
    PreparationPlan(
      id: id,
      competition: CompetitionSnapshot(id: compId, name: 'C', category: '计算机类',
        rulesSummary: CompetitionRulesSummary(signupTime: '', contestTime: '', teamSize: '', format: '', organizer: '', officialUrl: null)),
      targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.beginner,
      status: status,
      phases: const [],
      createdAt: DateTime(2026, 6, 28), updatedAt: DateTime(2026, 6, 28),
    );

void main() {
  late LocalPreparationPlanRepository repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalPreparationPlanRepository(SharedPreferencesLocalStore(await SharedPreferences.getInstance()));
  });

  test('save 后 list/watch 可见', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    expect(repo.list().length, 1);
    final firstEvt = await repo.watch().first;
    expect(firstEvt.length, 1);
  });

  test('activeForCompetition 返回进行中计划', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    final a = repo.activeForCompetition('c1');
    expect(a, isNotNull);
    expect(a!.id, 'p1');
    expect(repo.activeForCompetition('c2'), isNull);
  });

  test('归档后 activeForCompetition 为 null', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    await repo.archive('p1');
    expect(repo.activeForCompetition('c1'), isNull);
    expect(repo.findById('p1')!.status, PreparationPlanStatus.archived);
  });

  test('同一竞赛最多一个 active：save 第二个同竞赛 plan 仍存为独立条目（由生成器/页面保证唯一，仓库不强制）', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    await repo.save(_plan(id: 'p2', compId: 'c1'));
    expect(repo.list().length, 2);
  });

  test('delete 移除', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    await repo.delete('p1');
    expect(repo.list(), isEmpty);
  });

  test('损坏数据降级忽略', () async {
    // 直接写坏 JSON 到 store
    final store = SharedPreferencesLocalStore(await SharedPreferences.getInstance());
    await store.setJsonList(LocalPreparationPlanRepository.storageKey, [
      {'id': 'bad', 'competition': null}, // 缺字段
    ]);
    expect(repo.list(), isEmpty);
  });
}
