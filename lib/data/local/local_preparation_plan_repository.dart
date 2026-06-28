import 'dart:async';

import '../../core/storage/local_store.dart';
import '../../domain/entities/preparation_plan.dart';
import '../../domain/repositories/preparation_plan_repository.dart';

class LocalPreparationPlanRepository implements PreparationPlanRepository {
  LocalPreparationPlanRepository(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const String storageKey = 'competition_preparation_plans.v1';

  final LocalStore _store;
  final DateTime Function() _now;
  final StreamController<List<PreparationPlan>> _controller =
      StreamController<List<PreparationPlan>>.broadcast();

  @override
  List<PreparationPlan> list() => _readAll();

  @override
  PreparationPlan? findById(String id) {
    for (final plan in list()) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  @override
  PreparationPlan? activeForCompetition(String competitionId) {
    for (final plan in list()) {
      if (plan.status == PreparationPlanStatus.active &&
          plan.competition.id == competitionId) {
        return plan;
      }
    }
    return null;
  }

  @override
  Stream<List<PreparationPlan>> watch() async* {
    yield list();
    yield* _controller.stream;
  }

  @override
  Future<PreparationPlan> save(PreparationPlan plan) async {
    final updated = plan.copyWith(updatedAt: _now());
    final plans = [
      updated,
      ...list().where((current) => current.id != plan.id),
    ];
    await _writeAll(plans);
    return updated;
  }

  @override
  Future<void> archive(String id) async {
    final plan = findById(id);
    if (plan == null) return;
    await save(
      plan.copyWith(
        status: PreparationPlanStatus.archived,
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    final plans = list().where((plan) => plan.id != id).toList();
    await _writeAll(plans);
  }

  void dispose() => _controller.close();

  List<PreparationPlan> _readAll() {
    final raw = _store.getJsonList(storageKey);
    if (raw == null) return const [];

    final plans = <PreparationPlan>[];
    for (final entry in raw) {
      final plan = _parsePlan(entry);
      if (plan != null) plans.add(plan);
    }
    return plans;
  }

  PreparationPlan? _parsePlan(Object? entry) {
    if (entry is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(entry);
      return PreparationPlan.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeAll(List<PreparationPlan> plans) async {
    await _store.setJsonList(
      storageKey,
      plans.map((plan) => plan.toJson()).toList(growable: false),
    );
    _controller.add(List<PreparationPlan>.unmodifiable(plans));
  }
}
