import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';

void main() {
  group('rank getter', () {
    test('none -> null', () {
      expect(const AcademicScore().rank, isNull);
    });
    test('percent=5 -> 前 5%', () {
      const score = AcademicScore(rankMode: RankMode.percent, percent: 5);
      expect(score.rank, '前 5%');
    });
    test('ordinal 3/120 -> 3/120', () {
      const score = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      expect(score.rank, '3/120');
    });
    test('percent mode 但 percent=null -> null', () {
      const score = AcademicScore(rankMode: RankMode.percent);
      expect(score.rank, isNull);
    });
    test('ordinal 缺 position -> null', () {
      const score = AcademicScore(rankMode: RankMode.ordinal, rankTotal: 120);
      expect(score.rank, isNull);
    });
    test('ordinal 缺 total -> null', () {
      const score = AcademicScore(rankMode: RankMode.ordinal, rankPosition: 3);
      expect(score.rank, isNull);
    });
  });

  group('isEmpty', () {
    test('全空 -> true', () {
      expect(const AcademicScore().isEmpty, isTrue);
    });
    test('只设 gpa -> false', () {
      const score = AcademicScore(gpa: 3.8);
      expect(score.isEmpty, isFalse);
    });
    test('mode=none -> true（rank 为 null）', () {
      const score = AcademicScore(rankMode: RankMode.none);
      expect(score.isEmpty, isTrue);
    });
    test('percent=5 -> false', () {
      const score = AcademicScore(rankMode: RankMode.percent, percent: 5);
      expect(score.isEmpty, isFalse);
    });
  });

  group('withGpa / withScale / withRank', () {
    test('withGpa 保留排名字段', () {
      const base = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      final out = base.withGpa(3.9);
      expect(out.gpa, 3.9);
      expect(out.rankMode, RankMode.ordinal);
      expect(out.rankPosition, 3);
      expect(out.rankTotal, 120);
    });
    test('withScale 保留排名字段', () {
      const base = AcademicScore(
        rankMode: RankMode.percent, percent: 5,
      );
      final out = base.withScale(4.0);
      expect(out.scale, 4.0);
      expect(out.rankMode, RankMode.percent);
      expect(out.percent, 5);
    });
    test('withRank(mode: none) 清空三件套', () {
      const base = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      final out = base.withRank(mode: RankMode.none);
      expect(out.rankMode, RankMode.none);
      expect(out.percent, isNull);
      expect(out.rankPosition, isNull);
      expect(out.rankTotal, isNull);
      expect(out.rank, isNull);
    });
    test('withRank(mode: percent) 未传字段保留原值（回带语义）', () {
      // 从名次切到百分制：切回时名次旧值仍由 value 带回
      const base = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      final out = base.withRank(mode: RankMode.percent);
      expect(out.rankMode, RankMode.percent);
      expect(out.rankPosition, 3);   // 保留
      expect(out.rankTotal, 120);    // 保留
    });
    test('withRank 设置 percent', () {
      const base = AcademicScore();
      final out = base.withRank(mode: RankMode.percent, percent: 5);
      expect(out.rankMode, RankMode.percent);
      expect(out.percent, 5);
      expect(out.rank, '前 5%');
    });
  });

  group('toJson / fromJson 往返', () {
    test('percent 模式往返', () {
      const score = AcademicScore(
        gpa: 3.8, scale: 4.0, rankMode: RankMode.percent, percent: 5,
      );
      final out = AcademicScore.fromJson(score.toJson());
      expect(out.gpa, 3.8);
      expect(out.scale, 4.0);
      expect(out.rankMode, RankMode.percent);
      expect(out.percent, 5);
      expect(out.rank, '前 5%');
    });
    test('ordinal 模式往返', () {
      const score = AcademicScore(
        rankMode: RankMode.ordinal, rankPosition: 3, rankTotal: 120,
      );
      final out = AcademicScore.fromJson(score.toJson());
      expect(out.rankMode, RankMode.ordinal);
      expect(out.rankPosition, 3);
      expect(out.rankTotal, 120);
      expect(out.rank, '3/120');
    });
    test('none 模式不写排名字段', () {
      const score = AcademicScore(gpa: 3.8);
      final json = score.toJson();
      expect(json.containsKey('rank_mode'), isFalse);
      expect(json.containsKey('percent'), isFalse);
      expect(json.containsKey('rank_position'), isFalse);
      expect(json.containsKey('rank_total'), isFalse);
      expect(json.containsKey('rank'), isFalse);
    });
    test('旧版只存 rank 字符串的 JSON 被忽略，rankMode 默认 none', () {
      // 开发阶段清空：旧 rank 字符串不解析
      final out = AcademicScore.fromJson({
        'gpa': 3.8,
        'rank': '前 5%',
      });
      expect(out.gpa, 3.8);
      expect(out.rankMode, RankMode.none);
      expect(out.rank, isNull);
    });
  });
}
