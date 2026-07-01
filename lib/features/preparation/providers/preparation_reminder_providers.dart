import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/platform/preparation_reminder_platform.dart';
import '../../../data/local/preparation_reminder_store.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/entities/preparation_reminder.dart';
import '../../../domain/services/preparation_reminder_builder.dart';
import 'preparation_providers.dart';

final preparationReminderPlatformProvider =
    Provider<PreparationReminderPlatform>(
      (_) => MethodChannelPreparationReminderPlatform(),
    );

final preparationReminderStoreProvider = Provider<PreparationReminderStore>(
  (ref) => PreparationReminderStore(ref.watch(localStoreProvider)),
);

final reminderPreferencesProvider =
    NotifierProvider<ReminderPreferencesNotifier, ReminderPreferences>(
      ReminderPreferencesNotifier.new,
    );

class ReminderPreferencesNotifier extends Notifier<ReminderPreferences> {
  PreparationReminderStore get _store =>
      ref.read(preparationReminderStoreProvider);

  @override
  ReminderPreferences build() => _store.loadPreferences();

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _store.savePreferences(state);
    await ref.read(preparationReminderPlatformProvider).updateSchedule(state);
  }

  Future<void> setTime({required int hour, required int minute}) async {
    state = state.copyWith(hour: hour, minute: minute);
    await _store.savePreferences(state);
    await ref.read(preparationReminderPlatformProvider).updateSchedule(state);
  }
}

final preparationReminderSyncProvider = Provider<void>((ref) {
  final repository = ref.watch(preparationPlanRepositoryProvider);
  final store = ref.watch(preparationReminderStoreProvider);
  final platform = ref.watch(preparationReminderPlatformProvider);
  const builder = PreparationReminderBuilder();
  Future<void> guard = Future<void>.value();

  Future<void> sync(List<PreparationPlan> plans) {
    guard = guard
        .then((_) async {
          final days = await store.reconcileActivityDays(plans);
          final snapshot = builder.build(
            plans: plans,
            activityDays: days,
            now: DateTime.now(),
          );
          await platform.syncSnapshot(snapshot);
        })
        .catchError((_) {});
    return guard;
  }

  final subscription = repository.watch().listen(sync);
  ref.onDispose(subscription.cancel);

  ref.listen<ReminderPreferences>(reminderPreferencesProvider, (_, next) {
    unawaited(platform.updateSchedule(next));
  });
  unawaited(platform.updateSchedule(ref.read(reminderPreferencesProvider)));
});
