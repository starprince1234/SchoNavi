/// 竞赛成果条目。仅 name 必填，其余可空（缺失 UI 显示「暂无信息」）。
class Competition {
  const Competition({required this.name, this.level, this.award, this.year});

  final String name; // 例 "ACM-ICPC 区域赛"
  final String? level; // 国际 / 国家级 / 省级 / 校级
  final String? award; // 例 "银牌"、"一等奖"
  final String? year; // 自由文本，例 "2024"

  Map<String, dynamic> toJson() => {
    'name': name,
    if (level != null) 'level': level,
    if (award != null) 'award': award,
    if (year != null) 'year': year,
  };

  factory Competition.fromJson(Map<String, dynamic> json) => Competition(
    name: (json['name'] as String?)?.trim() ?? '',
    level: _str(json['level']),
    award: _str(json['award']),
    year: _str(json['year']),
  );

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
}
