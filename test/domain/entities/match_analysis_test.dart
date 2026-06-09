import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';

void main() {
  test('MatchAnalysis 保存四部分', () {
    const analysis = MatchAnalysis(
      professorId: 'p_001',
      summary: '方向较契合。',
      strengths: ['研究方向一致'],
      gaps: ['缺少相关论文'],
      suggestions: ['补读该方向综述'],
    );

    expect(analysis.professorId, 'p_001');
    expect(analysis.summary, isNotEmpty);
    expect(analysis.strengths, ['研究方向一致']);
    expect(analysis.gaps, ['缺少相关论文']);
    expect(analysis.suggestions, ['补读该方向综述']);
  });
}
