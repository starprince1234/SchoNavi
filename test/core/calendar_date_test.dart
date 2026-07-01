import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/calendar_date.dart';

void main() {
  test('normalize 截掉时分秒到本地零点', () {
    final d = DateTime(2026, 5, 3, 13, 45, 9);
    expect(CalendarDate.normalize(d), DateTime(2026, 5, 3));
  });

  test('toIsoDay 输出 YYYY-MM-DD', () {
    expect(CalendarDate.toIsoDay(DateTime(2026, 5, 3)), '2026-05-03');
    expect(CalendarDate.toIsoDay(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('parseIsoDay 解析回本地零点 DateTime', () {
    expect(CalendarDate.parseIsoDay('2026-05-03'), DateTime(2026, 5, 3));
  });

  test('parseIsoDay 拒绝 date-time 混用', () {
    expect(
      () => CalendarDate.parseIsoDay('2026-05-03T10:00:00Z'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CalendarDate.parseIsoDay('not-a-date'),
      throwsA(isA<FormatException>()),
    );
  });

  test('clampDay 闭区间夹取', () {
    final lo = DateTime(2026, 5, 1);
    final hi = DateTime(2026, 5, 10);
    expect(CalendarDate.clampDay(DateTime(2026, 4, 30), lo, hi), lo);
    expect(CalendarDate.clampDay(DateTime(2026, 5, 20), lo, hi), hi);
    expect(
      CalendarDate.clampDay(DateTime(2026, 5, 5), lo, hi),
      DateTime(2026, 5, 5),
    );
  });

  test('toIsoDay/parseIsoDay 往返一致', () {
    final d = DateTime(2026, 6, 29);
    expect(CalendarDate.parseIsoDay(CalendarDate.toIsoDay(d)), d);
  });
}
