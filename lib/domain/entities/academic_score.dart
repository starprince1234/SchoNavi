/// 学业成绩：GPA + 量纲 + 排名（均可空）。排名以结构化字段存储，rank 为展示用计算 getter。
enum RankMode { none, percent, ordinal }

class AcademicScore {
  const AcademicScore({
    this.gpa,
    this.scale,
    this.rankMode = RankMode.none,
    this.percent,
    this.rankPosition,
    this.rankTotal,
  });

  final double? gpa; // 例 3.8
  final double? scale; // 量纲：4.0 / 4.3 / 4.5 / 5.0 / 100
  final RankMode rankMode;
  final int? percent; // 1..100，rankMode==percent 时有值
  final int? rankPosition; // 1..rankTotal，rankMode==ordinal 时有值
  final int? rankTotal; // >=1，rankMode==ordinal 时有值

  /// 由结构化字段生成的展示串，下游推荐/套磁读它。
  String? get rank => switch (rankMode) {
    RankMode.none => null,
    RankMode.percent => percent == null ? null : '前 $percent%',
    RankMode.ordinal =>
      (rankPosition == null || rankTotal == null) ? null : '$rankPosition/$rankTotal',
  };

  bool get isEmpty => gpa == null && scale == null && rank == null;

  AcademicScore withGpa(double? gpa) => AcademicScore(
    gpa: gpa, scale: scale, rankMode: rankMode,
    percent: percent, rankPosition: rankPosition, rankTotal: rankTotal,
  );

  AcademicScore withScale(double? scale) => AcademicScore(
    gpa: gpa, scale: scale, rankMode: rankMode,
    percent: percent, rankPosition: rankPosition, rankTotal: rankTotal,
  );

  /// mode==none 时清空三件套；mode!=none 时未传字段保留原值（?? this.x）。
  AcademicScore withRank({
    required RankMode mode,
    int? percent,
    int? rankPosition,
    int? rankTotal,
  }) {
    if (mode == RankMode.none) {
      return AcademicScore(gpa: gpa, scale: scale, rankMode: RankMode.none);
    }
    return AcademicScore(
      gpa: gpa, scale: scale, rankMode: mode,
      percent: percent ?? this.percent,
      rankPosition: rankPosition ?? this.rankPosition,
      rankTotal: rankTotal ?? this.rankTotal,
    );
  }

  Map<String, dynamic> toJson() => {
    if (gpa != null) 'gpa': gpa,
    if (scale != null) 'scale': scale,
    if (rankMode != RankMode.none) 'rank_mode': rankMode.name,
    if (percent != null) 'percent': percent,
    if (rankPosition != null) 'rank_position': rankPosition,
    if (rankTotal != null) 'rank_total': rankTotal,
  };

  factory AcademicScore.fromJson(Map<String, dynamic> json) {
    // 旧版 rank 字符串忽略（开发阶段清空）
    return AcademicScore(
      gpa: (json['gpa'] as num?)?.toDouble(),
      scale: (json['scale'] as num?)?.toDouble(),
      rankMode: _rankModeFromName(json['rank_mode']),
      percent: (json['percent'] as num?)?.toInt(),
      rankPosition: (json['rank_position'] as num?)?.toInt(),
      rankTotal: (json['rank_total'] as num?)?.toInt(),
    );
  }
}

RankMode _rankModeFromName(Object? raw) {
  final name = raw?.toString();
  for (final m in RankMode.values) {
    if (m.name == name) return m;
  }
  return RankMode.none;
}
