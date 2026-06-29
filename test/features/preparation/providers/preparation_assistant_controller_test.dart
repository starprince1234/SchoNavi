import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

PreparationPlan _plan({String id = 'pp_1', int revision = 1}) => PreparationPlan(
      id: id,
      competition: CompetitionSnapshot(
        id: 'comp_demo',
        name: 'Demo',
        category: '计算机类',
        rulesSummary: CompetitionRulesSummary(
          signupTime: '', contestTime: '', teamSize: '', format: '', organizer: '', officialUrl: null,
        ),
      ),
      targetDate: DateTime(2026, 5, 30),
      timelineType: CompetitionTimelineType.submission,
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.intermediate,
      status: PreparationPlanStatus.active,
      phases: const [],
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      revision: revision,
    );

Future<ProviderContainer> _container({bool savePlan = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    initialAppConfigProvider.overrideWithValue(
      const AppConfig(
        dataSource: DataSource.llm,
        api: ApiConfig(baseUrl: 'https://fake.local'),
      ),
    ),
  ]);
  addTearDown(container.dispose);
  if (savePlan) {
    await container.read(preparationPlanRepositoryProvider).save(_plan(revision: 0));
  }
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('初始 state 为 empty，load 后注入 currentPlan', () async {
    final container = await _container(savePlan: true);
    final ctrl = container.read(
      preparationAssistantControllerProvider('pp_1').notifier,
    );
    // 首帧后 microtask load。
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.state.turns, isEmpty);
    expect(ctrl.state.sending, isFalse);
    expect(ctrl.state.currentPlan, isNotNull);
    expect(ctrl.state.currentPlan!.id, 'pp_1');
  });
}
