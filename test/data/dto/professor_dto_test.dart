import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/dto/professor_dto.dart';

void main() {
  final json = <String, dynamic>{
    'professor_id': 'p_001',
    'name': '张三',
    'university': '上海交通大学',
    'college': '电子信息与电气工程学院',
    'title': '教授',
    'research_fields': ['医学影像', '计算机视觉'],
    'bio': '主要研究医学影像分析。',
    'homepage_url': 'https://example.edu.cn',
    'source_url': 'https://example.edu.cn/src',
    'updated_at': '2026-06-01',
    'data_quality_score': 0.87,
  };

  test('fromJson -> toJson round-trips', () {
    final dto = ProfessorDto.fromJson(json);
    expect(dto.toJson(), equals(json));
  });

  test('toEntity maps fields and id', () {
    final p = ProfessorDto.fromJson(json).toEntity();
    expect(p.id, 'p_001');
    expect(p.name, '张三');
    expect(p.researchFields, ['医学影像', '计算机视觉']);
    expect(p.dataQualityScore, 0.87);
  });

  test('fromJson tolerates missing optional fields', () {
    final dto = ProfessorDto.fromJson({
      'professor_id': 'p_x',
      'name': '李四',
      'university': '某大学',
      'college': '某学院',
      'title': '讲师',
      'research_fields': <String>[],
    });
    final p = dto.toEntity();
    expect(p.bio, isNull);
    expect(p.homepageUrl, isNull);
    expect(p.researchFields, isEmpty);
  });
}
