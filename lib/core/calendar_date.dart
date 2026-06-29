/// 日历日期工具（spec §2.1）：无时区日历日期的规范化与 YYYY-MM-DD 编解码。
class CalendarDate {
  CalendarDate._();

  /// 规范化为本地零点 `DateTime(y, m, d)`。
  static DateTime normalize(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// 输出 `YYYY-MM-DD`。
  static String toIsoDay(DateTime value) {
    final d = normalize(value);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// 解析 `YYYY-MM-DD` 为本地零点 DateTime。拒绝带时间或非法格式。
  static DateTime parseIsoDay(String value) {
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(value)) {
      throw const FormatException('expected YYYY-MM-DD calendar date');
    }
    return DateTime.parse(value);
  }

  /// 闭区间夹取。
  static DateTime clampDay(DateTime v, DateTime lo, DateTime hi) {
    if (v.isBefore(lo)) return lo;
    if (v.isAfter(hi)) return hi;
    return v;
  }
}
