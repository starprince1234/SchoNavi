enum ResearchType { paper, project, patent, other }

ResearchType researchTypeFromString(String? raw) => switch (raw?.trim()) {
  'paper' || '论文' => ResearchType.paper,
  'project' || '项目' => ResearchType.project,
  'patent' || '专利' => ResearchType.patent,
  _ => ResearchType.other,
};

/// 科研成果条目（论文/项目/专利）。仅 title 必填。
class ResearchItem {
  const ResearchItem({
    required this.type,
    required this.title,
    this.role,
    this.venueOrStatus,
    this.year,
  });

  final ResearchType type;
  final String title;
  final String? role; // 例 "第一作者"、"项目负责人"
  final String? venueOrStatus; // 例 "EI 会议 / 已发表 / 在投"
  final String? year;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    if (role != null) 'role': role,
    if (venueOrStatus != null) 'venueOrStatus': venueOrStatus,
    if (year != null) 'year': year,
  };

  factory ResearchItem.fromJson(Map<String, dynamic> json) => ResearchItem(
    type: researchTypeFromString(json['type'] as String?),
    title: (json['title'] as String?)?.trim() ?? '',
    role: _str(json['role']),
    venueOrStatus: _str(json['venueOrStatus']),
    year: _str(json['year']),
  );

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
}
