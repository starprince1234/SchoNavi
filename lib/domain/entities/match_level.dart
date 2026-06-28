/// 匹配等级。API 以中文「高/中/低」表示。
enum MatchLevel {
  high('高'),
  medium('中'),
  low('低');

  const MatchLevel(this.label);

  final String label;

  static MatchLevel fromLabel(String value) {
    switch (value) {
      case '高':
        return MatchLevel.high;
      case '低':
        return MatchLevel.low;
      case '中':
      default:
        return MatchLevel.medium;
    }
  }

  /// 由归一化匹配分派生等级：≥0.8 high、≥0.6 medium、其余 low。
  static MatchLevel fromScore(double score) {
    final s = score.clamp(0.0, 1.0);
    if (s >= 0.8) return MatchLevel.high;
    if (s >= 0.6) return MatchLevel.medium;
    return MatchLevel.low;
  }
}
