import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/dto/quick_actions_dto.dart';
import 'package:scho_navi/data/dto/route_need_dto.dart';

void main() {
  group('QuickActionsRequestDto', () {
    test('followUp 写入 follow_up 字段', () {
      final json = const QuickActionsRequestDto(followUp: '换一批').toJson();
      expect(json['follow_up'], '换一批');
      expect(json.containsKey('last_recommendations'), isFalse);
    });

    test('lastRecommendations 非 null 时写入 last_recommendations', () {
      final json = QuickActionsRequestDto(
        followUp: '只看北京',
        lastRecommendations: [
          const RecommendationRecapDto(
            professorId: 'p_001',
            name: '张三',
            university: '清华大学',
            researchFields: ['计算机视觉'],
          ),
        ],
      ).toJson();
      expect(json['follow_up'], '只看北京');
      final recs = json['last_recommendations'] as List;
      expect(recs, hasLength(1));
      expect((recs.single as Map)['professor_id'], 'p_001');
      expect((recs.single as Map)['research_fields'], ['计算机视觉']);
    });
  });

  group('QuickActionsResponseDto.fromJson', () {
    test('解码 quick_actions 字符串列表', () {
      final dto = QuickActionsResponseDto.fromJson(const {
        'quick_actions': ['换一批', '偏应用'],
      });
      expect(dto.quickActions, ['换一批', '偏应用']);
    });

    test('quick_actions 缺省视为空列表', () {
      final dto = QuickActionsResponseDto.fromJson(const <String, dynamic>{});
      expect(dto.quickActions, isEmpty);
    });

    test('quick_actions 类型错误视为空列表', () {
      final dto = QuickActionsResponseDto.fromJson(const {
        'quick_actions': 'not-a-list',
      });
      expect(dto.quickActions, isEmpty);
    });

    test('过滤 null 与空字符串元素', () {
      final dto = QuickActionsResponseDto.fromJson(const {
        'quick_actions': ['换一批', null, '', '偏应用'],
      });
      expect(dto.quickActions, ['换一批', '偏应用']);
    });
  });
}
