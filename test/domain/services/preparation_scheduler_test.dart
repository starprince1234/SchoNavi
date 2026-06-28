// test/domain/services/preparation_scheduler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_template.dart';
import 'package:scho_navi/domain/services/preparation_scheduler.dart';

List<PreparationTemplatePhase> _phases() => [
      const PreparationTemplatePhase(
          key: 'a', title: 'A', weight: 0.2, requiredTasks: [], optionalTasks: []),
      const PreparationTemplatePhase(
          key: 'b', title: 'B', weight: 0.3, requiredTasks: [], optionalTasks: []),
      const PreparationTemplatePhase(
          key: 'c', title: 'C', weight: 0.5, requiredTasks: [], optionalTasks: []),
    ];

void main() {
  group('PreparationScheduler.schedule', () {
    test('宽裕：按权重分配，覆盖 [today, targetDate]', () {
      final s = PreparationScheduler.schedule(
        phases: _phases(),
        today: DateTime(2026, 6, 28),
        targetDate: DateTime(2026, 9, 1),
      );
      expect(s.length, 3);
      expect(s.first.startDate, DateTime(2026, 6, 28));
      expect(s.last.endDate, DateTime(2026, 9, 1));
      // 阶段连续不重叠
      for (var i = 1; i < s.length; i++) {
        expect(s[i].startDate.isAfter(s[i - 1].startDate), isTrue);
      }
    });

    test('压缩：5 天 3 阶段 -> 合并相邻使每段 >=1 天', () {
      final today = DateTime(2026, 6, 28);
      final s = PreparationScheduler.schedule(
        phases: _phases(),
        today: today,
        targetDate: today.add(const Duration(days: 5)),
      );
      expect(s.length, lessThanOrEqualTo(5));
      for (final p in s) {
        expect(p.endDate.difference(p.startDate).inDays, greaterThanOrEqualTo(0));
      }
      expect(s.first.startDate, today);
      expect(s.last.endDate, today.add(const Duration(days: 5)));
    });

    test('极短：1 天 -> 合并为 1 段', () {
      final today = DateTime(2026, 6, 28);
      final s = PreparationScheduler.schedule(
        phases: _phases(),
        today: today,
        targetDate: today,
      );
      expect(s.length, 1);
      expect(s.first.startDate, today);
      expect(s.first.endDate, today);
    });

    test('相邻阶段连续无重叠且覆盖 [today, targetDate]', () {
      final today = DateTime(2026, 6, 28);
      final target = DateTime(2026, 9, 1);
      final s = PreparationScheduler.schedule(
        phases: _phases(),
        today: today,
        targetDate: target,
      );
      expect(s.first.startDate, today);
      expect(s.last.endDate, target);
      for (var i = 1; i < s.length; i++) {
        // 后一段 startDate 应紧接前一段 endDate 之后一天
        expect(
          s[i].startDate.difference(s[i - 1].endDate).inDays,
          1,
        );
      }
    });

    test('压缩到极短：totalDays=2 且 3 阶段 -> 合并使 finalLen <= 2', () {
      final today = DateTime(2026, 6, 28);
      final s = PreparationScheduler.schedule(
        phases: _phases(),
        today: today,
        targetDate: today.add(const Duration(days: 2)),
      );
      expect(s.length, lessThanOrEqualTo(2));
      expect(s.first.startDate, today);
      expect(s.last.endDate, today.add(const Duration(days: 2)));
      for (final p in s) {
        expect(p.endDate.difference(p.startDate).inDays, greaterThanOrEqualTo(0));
      }
    });
  });

  group('PreparationScheduler.isTightSchedule', () {
    test('< 14 天为紧', () {
      expect(
        PreparationScheduler.isTightSchedule(
            DateTime(2026, 6, 28), DateTime(2026, 7, 5)),
        isTrue,
      );
    });

    test('>= 14 天非紧', () {
      expect(
        PreparationScheduler.isTightSchedule(
            DateTime(2026, 6, 28), DateTime(2026, 9, 1)),
        isFalse,
      );
    });

    test('恰好 14 天非紧', () {
      expect(
        PreparationScheduler.isTightSchedule(
            DateTime(2026, 6, 28), DateTime(2026, 7, 12)),
        isFalse,
      );
    });
  });
}
