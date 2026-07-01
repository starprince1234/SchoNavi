import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/dto/profile_dtos.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';

void main() {
  group('AcademicScoreDto 往返', () {
    test('percent 模式 entity -> dto -> entity 无损', () {
      const score = AcademicScore(
        gpa: 3.8,
        scale: 4.0,
        rankMode: RankMode.percent,
        percent: 5,
      );
      final dto = AcademicScoreDto.fromEntity(score);
      expect(dto.gpa, 3.8);
      expect(dto.scale, 4.0);
      expect(dto.rankMode, RankMode.percent);
      expect(dto.percent, 5);
      final back = dto.toEntity();
      expect(back.rank, '前 5%');
      expect(back.percent, 5);
    });
    test('ordinal 模式 json 往返', () {
      final dto = AcademicScoreDto.fromJson({
        'gpa': 3.8,
        'rank_mode': 'ordinal',
        'rank_position': 3,
        'rank_total': 120,
      });
      expect(dto.rankMode, RankMode.ordinal);
      expect(dto.rankPosition, 3);
      expect(dto.rankTotal, 120);
      final json = dto.toJson();
      expect(json['rank_mode'], 'ordinal');
      expect(json['rank_position'], 3);
      expect(json['rank_total'], 120);
      expect(json.containsKey('rank'), isFalse);
    });
    test('none 模式不写排名字段', () {
      const score = AcademicScore(gpa: 3.8);
      final json = AcademicScoreDto.fromEntity(score).toJson();
      expect(json.containsKey('rank_mode'), isFalse);
      expect(json.containsKey('rank'), isFalse);
    });
    test('旧版 rank 字符串被忽略', () {
      final dto = AcademicScoreDto.fromJson({'rank': '前 5%'});
      expect(dto.rankMode, isNull);
      final entity = dto.toEntity();
      expect(entity.rank, isNull);
    });
  });
}
