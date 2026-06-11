import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_profile_extraction_repository.dart';
import 'package:scho_navi/domain/entities/research_item.dart';

class _FakeLlm implements LlmClient {
  _FakeLlm(this._result);

  final Result<String> _result;
  bool? lastJsonMode;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    lastJsonMode = jsonMode;
    return _result;
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
}

void main() {
  test('解析竞赛与科研条目', () async {
    final content = jsonEncode({
      'competitions': [
        {'name': 'ACM-ICPC 区域赛', 'level': '国家级', 'award': '银牌', 'year': '2024'},
      ],
      'research': [
        {
          'type': 'paper',
          'title': '深度学习用于医学影像',
          'role': '第一作者',
          'venueOrStatus': 'EI 会议 / 已发表',
          'year': '2024',
        },
      ],
    });
    final repo = AiProfileExtractionRepository(_FakeLlm(Success(content)));

    final draft = (await repo.extract(rawText: '随便一段自述') as Success).data;

    expect(draft.competitions.single.name, 'ACM-ICPC 区域赛');
    expect(draft.competitions.single.award, '银牌');
    expect(draft.research.single.type, ResearchType.paper);
    expect(draft.research.single.role, '第一作者');
  });

  test('使用 JSON 模式', () async {
    final fake = _FakeLlm(const Success('{"competitions":[],"research":[]}'));
    await AiProfileExtractionRepository(fake).extract(rawText: 'x');
    expect(fake.lastJsonMode, isTrue);
  });

  test('丢弃缺名竞赛/缺标题科研', () async {
    final content = jsonEncode({
      'competitions': [
        {'level': '省级'},
        {'name': '挑战杯', 'award': '一等奖'},
      ],
      'research': [
        {'type': 'project', 'role': '负责人'},
      ],
    });
    final repo = AiProfileExtractionRepository(_FakeLlm(Success(content)));

    final draft = (await repo.extract(rawText: 'x') as Success).data;

    expect(draft.competitions.map((c) => c.name), ['挑战杯']);
    expect(draft.research, isEmpty);
  });

  test('坏 JSON 返回 ServerException', () async {
    final repo = AiProfileExtractionRepository(_FakeLlm(const Success('not json')));
    final res = await repo.extract(rawText: 'x');
    expect((res as Failure).error, isA<ServerException>());
  });

  test('LLM 失败透传', () async {
    final repo =
        AiProfileExtractionRepository(_FakeLlm(const Failure(NetworkException())));
    final res = await repo.extract(rawText: 'x');
    expect((res as Failure).error, isA<NetworkException>());
  });
}
