import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/services/competition_category_normalizer.dart';

void main() {
  test('别名归一', () {
    expect(CompetitionCategoryNormalizer.normalize('电子信息类'), '电子与信息类');
    expect(CompetitionCategoryNormalizer.normalize('创新创业类'), '综合与创业类');
    expect(CompetitionCategoryNormalizer.normalize('计算机类'), '计算机类');
  });
  test('未知类目原样返回', () {
    expect(CompetitionCategoryNormalizer.normalize('神秘类'), '神秘类');
  });
}
