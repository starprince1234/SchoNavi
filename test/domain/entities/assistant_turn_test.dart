import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/assistant_turn.dart';

void main() {
  test('toJson/fromJson 往返 requestId', () {
    final turn = AssistantTurn(
      id: 'turn_1',
      planId: 'pp_1',
      userMessage: '问',
      reply: '答',
      createdAt: DateTime.utc(2026, 6, 30),
      cardStatuses: const {},
      requestId: 'req_abc',
    );
    final decoded = AssistantTurn.fromJson(turn.toJson());
    expect(decoded.requestId, 'req_abc');
  });

  test('旧持久化数据缺 request_id 默认空串', () {
    final json = <String, dynamic>{
      'id': 'turn_old',
      'plan_id': 'pp_1',
      'user_message': '问',
      'reply': '答',
      'created_at': '2026-06-30T00:00:00.000Z',
      'error': false,
      'card_statuses': <String, dynamic>{},
    };
    final decoded = AssistantTurn.fromJson(json);
    expect(decoded.requestId, '');
  });
}
