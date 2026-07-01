import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ProviderContainer> makeContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('save 后 list stream 推送', () async {
    final container = await makeContainer();
    // StreamProvider 懒初始化：需先建立订阅，stream 的首帧（list()）才会发出；
    // 否则 .future 永远在 loading 状态。生产中由 widget ConsumerSubscription 持有订阅。
    final sub = container.listen(preparationPlanListProvider, (_, _) {});
    addTearDown(sub.close);
    final repo = container.read(preparationPlanRepositoryProvider);
    await repo.save(
      PreparationPlan(
        id: 'p1',
        competition: CompetitionSnapshot(
          id: 'c1',
          name: 'C',
          category: '计算机类',
          rulesSummary: CompetitionRulesSummary(
            signupTime: '',
            contestTime: '',
            teamSize: '',
            format: '',
            organizer: '',
            officialUrl: null,
          ),
        ),
        targetDate: DateTime(2026, 9, 1),
        weeklyCommitment: WeeklyCommitment.hours6to10,
        experienceLevel: ExperienceLevel.beginner,
        status: PreparationPlanStatus.active,
        phases: const [],
        tightSchedule: false,
        overload: false,
        createdAt: DateTime(2026, 6, 28),
        updatedAt: DateTime(2026, 6, 28),
      ),
    );
    final list = await container.read(preparationPlanListProvider.future);
    expect(list.length, 1);
  });

  test('activePlanForCompetition 命中', () async {
    final container = await makeContainer();
    final repo = container.read(preparationPlanRepositoryProvider);
    await repo.save(
      PreparationPlan(
        id: 'p1',
        competition: CompetitionSnapshot(
          id: 'c1',
          name: 'C',
          category: '计算机类',
          rulesSummary: CompetitionRulesSummary(
            signupTime: '',
            contestTime: '',
            teamSize: '',
            format: '',
            organizer: '',
            officialUrl: null,
          ),
        ),
        targetDate: DateTime(2026, 9, 1),
        weeklyCommitment: WeeklyCommitment.hours6to10,
        experienceLevel: ExperienceLevel.beginner,
        status: PreparationPlanStatus.active,
        phases: const [],
        tightSchedule: false,
        overload: false,
        createdAt: DateTime(2026, 6, 28),
        updatedAt: DateTime(2026, 6, 28),
      ),
    );
    expect(container.read(activePlanForCompetitionProvider('c1'))?.id, 'p1');
  });
}
