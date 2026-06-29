// lib/domain/services/preparation_scheduler.dart
import 'package:scho_navi/domain/entities/preparation_template.dart';

/// Deterministic preparation scheduler (spec §7.3 / D9).
///
/// Distributes the time window `[today, targetDate]` across the template's
/// phases by their `weight`. When the window is too short to fit one phase
/// per day, adjacent phases are merged (from the end) so each final segment
/// gets at least one day.
class PreparationScheduler {
  PreparationScheduler._();

  /// A scheduled phase segment.
  ///
  /// 将闭区间 `[today, segmentEnd]` 按阶段权重分配给各阶段（spec §7.3）。
  /// 当窗口过短无法每阶段至少一天时，自末尾起合并相邻阶段，保证每段 >=1 天。
  /// `segmentEnd` 表意为该分段截止日；调用方可将其视为 targetDate（pre 段）
  /// 或 defenseDate（defense 段）。
  static List<({String key, DateTime startDate, DateTime endDate})>
  scheduleSegment({
    required List<PreparationTemplatePhase> phases,
    required DateTime today,
    required DateTime segmentEnd,
  }) {
    if (phases.isEmpty) {
      return const [];
    }

    final totalDays = segmentEnd.difference(today).inDays;

    // Single-day or non-positive window: collapse everything into one segment
    // [today, today]. Clamp targetDate to today to keep the output sane even
    // when targetDate < today (defensive).
    if (totalDays <= 0) {
      return [
        (
          key: phases.map((p) => p.key).join('+'),
          startDate: today,
          endDate: today,
        ),
      ];
    }

    // --- Phase merging (when window is too tight) -------------------------
    // Build mutable working copies of keys/weights.
    final keys = phases.map((p) => p.key).toList();
    final weights = phases.map((p) => p.weight).toList();

    // Merge from the end until final length fits the window (finalLen <=
    // totalDays, with at least one segment). Each merged phase keeps the front
    // key and sums the weights; merged key = frontKey+backKey.
    while (keys.length > totalDays && keys.length > 1) {
      final backKey = keys.removeLast();
      final backWeight = weights.removeLast();
      final frontIdx = keys.length - 1;
      keys[frontIdx] = '${keys[frontIdx]}+$backKey';
      weights[frontIdx] += backWeight;
    }

    // --- Day allocation by normalized weight -------------------------------
    final wSum = weights.fold<double>(0, (a, w) => a + w);
    final days = List<int>.generate(keys.length, (i) {
      final raw = wSum > 0
          ? weights[i] / wSum * totalDays
          : totalDays / keys.length;
      final d = raw.round();
      // Every phase must keep at least one day.
      return d < 1 ? 1 : d;
    });

    // Fix rounding remainder so the sum equals totalDays exactly. Add or
    // subtract from the phase with the largest weight (stable, deterministic).
    var diff = totalDays - days.fold<int>(0, (a, d) => a + d);
    if (diff != 0) {
      final pivot = _argMaxWeightIndex(weights);
      // When diff > 0 we add days; when diff < 0 we remove, but never below 1.
      // Removing could underflow if all phases are 1; loop guards with > 1.
      while (diff > 0) {
        days[pivot] += 1;
        diff -= 1;
      }
      while (diff < 0 && days[pivot] > 1) {
        days[pivot] -= 1;
        diff += 1;
      }
      // If we still have a deficit because the pivot couldn't give more, fall
      // back to spreading across phases to satisfy the invariant exactly.
      var i = 0;
      while (diff < 0) {
        if (days[i] > 1) {
          days[i] -= 1;
          diff += 1;
        }
        i = (i + 1) % days.length;
        // safety: avoid infinite loop on degenerate inputs
        if (i == 0 && days.every((d) => d == 1)) break;
      }
    }

    // --- Build contiguous segments ----------------------------------------
    // Each segment i spans `days[i]` day-transitions starting at `cursor`;
    // the next segment starts the day after. The last segment's endDate is
    // forced to `segmentEnd` so the whole window is covered exactly.
    final out = <({String key, DateTime startDate, DateTime endDate})>[];
    var cursor = today;
    for (var i = 0; i < keys.length; i++) {
      final isLast = i == keys.length - 1;
      final endDate = isLast
          ? segmentEnd
          : cursor.add(Duration(days: days[i] - 1));
      out.add((key: keys[i], startDate: cursor, endDate: endDate));
      cursor = endDate.add(const Duration(days: 1));
    }

    return out;
  }

  /// 兼容旧调用（详情页 `_reschedulePhases` 等）：转发到 [scheduleSegment]，
  /// `targetDate` 即单段 `segmentEnd`。新代码应直接用 [scheduleSegment]。
  static List<({String key, DateTime startDate, DateTime endDate})> schedule({
    required List<PreparationTemplatePhase> phases,
    required DateTime today,
    required DateTime targetDate,
  }) => scheduleSegment(phases: phases, today: today, segmentEnd: targetDate);

  /// Returns `true` when the window between [today] and [targetDate] is
  /// fewer than 14 days (a "tight" schedule that needs compression).
  static bool isTightSchedule(DateTime today, DateTime targetDate) {
    final totalDays = targetDate.difference(today).inDays;
    return totalDays < 14;
  }

  /// Index of the largest weight (ties go to the earliest phase for
  /// determinism).
  static int _argMaxWeightIndex(List<double> weights) {
    var idx = 0;
    for (var i = 1; i < weights.length; i++) {
      if (weights[i] > weights[idx]) {
        idx = i;
      }
    }
    return idx;
  }
}
