import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_comparison_repository.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';

class _FakeLlm implements LlmClient {
  const _FakeLlm(this._result);

  final Result<String> _result;
  static List<LlmMessage>? lastMessages;
  static bool? lastJsonMode;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    lastMessages = messages;
    lastJsonMode = jsonMode;
    return _result;
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => const Stream.empty();
}

const _p1 = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
  bio: '研究医学影像。',
);
const _p3 = Professor(
  id: 'p_003',
  name: '王强',
  university: '北京大学',
  college: '信息科学技术学院',
  title: '教授',
  researchFields: ['自动驾驶', '深度学习'],
);

String _validJson() => jsonEncode({
  'rows': [
    {
      'dimension': '研究方向',
      'cells': {'p_001': '偏医学影像', 'p_003': '偏自动驾驶'},
    },
  ],
  'summary': '两位导师方向差异明显。',
  'suggestion': '若你更看重医学影像，可优先关注张三。',
});

void main() {
  setUp(() {
    _FakeLlm.lastMessages = null;
    _FakeLlm.lastJsonMode = null;
  });

  test('解析 rows/summary/suggestion，列顺序取传入导师，且用 JSON 模式', () async {
    final repo = AiComparisonRepository(_FakeLlm(Success(_validJson())));
    final result = await repo.compare(professors: [_p1, _p3]);
    final report = (result as Success<ComparisonReport>).data;

    expect(report.professorIds, ['p_001', 'p_003']);
    expect(report.rows.single.dimension, '研究方向');
    expect(report.rows.single.cells['p_001'], '偏医学影像');
    expect(report.summary, contains('差异'));
    expect(report.suggestion, contains('张三'));
    expect(_FakeLlm.lastJsonMode, isTrue);
  });

  test('接地：丢弃未知 professorId 的单元格', () async {
    final data = jsonEncode({
      'rows': [
        {
          'dimension': '研究方向',
          'cells': {'p_001': 'a', 'p_999': '伪造', 'p_003': 'b'},
        },
      ],
      'summary': 's',
      'suggestion': 'g',
    });
    final repo = AiComparisonRepository(_FakeLlm(Success(data)));
    final result = await repo.compare(professors: [_p1, _p3]);
    final report = (result as Success<ComparisonReport>).data;

    expect(report.rows.single.cells.keys.toSet(), {'p_001', 'p_003'});
  });

  test('user prompt 含两位导师方向（接地输入）', () async {
    await AiComparisonRepository(
      _FakeLlm(Success(_validJson())),
    ).compare(professors: [_p1, _p3]);

    final userMessage = _FakeLlm.lastMessages!.last.content;
    expect(userMessage, contains('医学影像'));
    expect(userMessage, contains('自动驾驶'));
    expect(userMessage, contains('p_001'));
    expect(userMessage, contains('p_003'));
  });

  test('坏 JSON -> Failure(ServerException)', () async {
    final repo = AiComparisonRepository(const _FakeLlm(Success('not json')));
    final result = await repo.compare(professors: [_p1, _p3]);

    expect((result as Failure).error, isA<ServerException>());
  });

  test('缺 summary/suggestion -> Failure(ServerException)', () async {
    final repo = AiComparisonRepository(
      _FakeLlm(Success(jsonEncode({'rows': [], 'summary': 's'}))),
    );
    final result = await repo.compare(professors: [_p1, _p3]);

    expect((result as Failure).error, isA<ServerException>());
  });

  test('LlmClient 失败透传', () async {
    final repo = AiComparisonRepository(
      const _FakeLlm(Failure(NetworkException())),
    );
    final result = await repo.compare(professors: [_p1, _p3]);

    expect((result as Failure).error, isA<NetworkException>());
  });
}
