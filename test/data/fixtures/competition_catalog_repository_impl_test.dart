import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/fixtures/competition_catalog_repository_impl.dart';

void main() {
  test('findById 命中', () {
    final repo = StaticCompetitionCatalogRepository();
    final c = repo.findById('comp_icpc');
    expect(c, isNotNull);
    expect(c!.name, 'ACM-ICPC 国际大学生程序设计竞赛');
    expect(c.category, '计算机类');
  });

  test('findById 未命中返回 null', () {
    final repo = StaticCompetitionCatalogRepository();
    expect(repo.findById('nope'), isNull);
  });
}
