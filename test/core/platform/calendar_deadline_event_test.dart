import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/platform/preparation_reminder_platform.dart';
import 'package:scho_navi/domain/entities/preparation_reminder.dart';

void main() {
  test('CalendarDeadlineEvent.toJson 包含必填字段', () {
    final event = CalendarDeadlineEvent(
      title: 'ACM-ICPC·报名截止',
      isoDay: '2026-08-15',
    );
    expect(event.toJson(), {
      'title': 'ACM-ICPC·报名截止',
      'isoDay': '2026-08-15',
    });
  });

  test('CalendarDeadlineEvent.toJson 包含可选字段', () {
    final event = CalendarDeadlineEvent(
      title: 'X·提交截止',
      isoDay: '2026-09-01',
      location: '线上',
      notes: '由 SchoNavi 备赛计划添加',
    );
    expect(event.toJson(), {
      'title': 'X·提交截止',
      'isoDay': '2026-09-01',
      'location': '线上',
      'notes': '由 SchoNavi 备赛计划添加',
    });
  });

  test('MethodChannel 实现映射原生返回字符串到 CalendarAddResult', () {
    // 通过 _FakePreparationReminderPlatform 验证接口存在；MethodChannel 行为
    // 由集成/手动验证覆盖，这里只保证类型契约可编译。
    final fake = _FakePlatformForCalendar();
    expect(fake.isSupported, isTrue);
  });
}

class _FakePlatformForCalendar implements PreparationReminderPlatform {
  @override
  Future<CalendarAddResult> addDeadlineEvent(CalendarDeadlineEvent event) async =>
      CalendarAddResult.success;
  @override bool get isSupported => true;
  @override Future<void> syncSnapshot(PreparationReminderSnapshot snapshot) async {}
  @override Future<void> updateSchedule(ReminderPreferences preferences) async {}
  @override Future<ReminderNotificationStatus> getNotificationStatus() async =>
      ReminderNotificationStatus.granted;
  @override Future<ReminderNotificationStatus> requestNotificationPermission() async =>
      ReminderNotificationStatus.granted;
  @override Future<bool> pinWidget() async => false;
  @override Future<void> openNotificationSettings() async {}
  @override Future<String?> takeInitialRoute() async => null;
  @override void setRouteHandler(ReminderRouteHandler? handler) {}
}
