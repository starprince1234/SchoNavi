import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_level.dart';

void main() {
  group('MatchLevel.fromScore', () {
    test('>=0.8 -> high', () {
      expect(MatchLevel.fromScore(0.8), MatchLevel.high);
      expect(MatchLevel.fromScore(0.95), MatchLevel.high);
      expect(MatchLevel.fromScore(1.0), MatchLevel.high);
    });

    test('>=0.6 <0.8 -> medium', () {
      expect(MatchLevel.fromScore(0.6), MatchLevel.medium);
      expect(MatchLevel.fromScore(0.79), MatchLevel.medium);
    });

    test('<0.6 -> low', () {
      expect(MatchLevel.fromScore(0.59), MatchLevel.low);
      expect(MatchLevel.fromScore(0.0), MatchLevel.low);
    });

    test('clamps out-of-range', () {
      expect(MatchLevel.fromScore(1.5), MatchLevel.high);
      expect(MatchLevel.fromScore(-0.2), MatchLevel.low);
    });
  });
}
