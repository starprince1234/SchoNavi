import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';
import 'package:scho_navi/data/local/preparation_reminder_store.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/entities/preparation_reminder.dart';

PreparationPlan completedPlan() => PreparationPlan(
  id: 'p1',
  competition: const CompetitionSnapshot(
    id: 'c1',
    name: '竞赛',
    category: '计算机类',
    rulesSummary: CompetitionRulesSummary(
      signupTime: '',
      contestTime: '',
      teamSize: '',
      format: '',
      organizer: '',
    ),
  ),
  targetDate: DateTime(2026, 8, 1),
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner,
  status: PreparationPlanStatus.active,
  phases: [
    PreparationPhase(
      key: 'phase',
      title: '训练',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 7, 1),
      tasks: [
        PreparationTask(
          id: 'task',
          title: '练习',
          kind: PreparationTaskKind.required,
          estimatedHours: 1,
          dueDate: DateTime(2026, 6, 30),
          completedAt: DateTime(2026, 6, 29, 23),
        ),
      ],
    ),
  ],
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 29),
);

void main() {
  late PreparationReminderStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = PreparationReminderStore(SharedPreferencesLocalStore(prefs));
  });

  test('提醒设置默认关闭且默认时间为 20:00', () {
    final preferences = store.loadPreferences();
    expect(preferences, isA<ReminderPreferences>());
    expect(preferences.enabled, isFalse);
    expect(preferences.hour, 20);
    expect(preferences.minute, 0);
  });

  test('从已完成任务补齐活动日期并保留历史日期', () async {
    final localStore = store;
    await localStore.reconcileActivityDays([completedPlan()]);
    final days = localStore.loadActivityDays();
    expect(days, contains('2026-06-29'));
  });
}
