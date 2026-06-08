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
}
