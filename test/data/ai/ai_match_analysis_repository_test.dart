import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_match_analysis_repository.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

class _FakeLlm implements LlmClient {
  _FakeLlm(this._result);

  final Result<String> _result;
  List<LlmMessage>? lastMessages;
  bool? lastJsonMode;

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

const _professor = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
  bio: '长期研究医学影像分析。',
);

String _validJson() => jsonEncode({
  'summary': '你的方向与该导师较契合。',
  'strengths': ['研究兴趣与医学影像一致'],
  'gaps': ['暂无相关论文'],
  'suggestions': ['补读医学影像综述'],
});

void main() {
  test('解析 summary/strengths/gaps/suggestions，且用 JSON 模式', () async {
    final llm = _FakeLlm(Success(_validJson()));
    final repo = AiMatchAnalysisRepository(llm);

    final result = await repo.analyze(
      professor: _professor,
      profile: const UserProfile(name: '李四', researchInterests: ['医学影像']),
    );

    final analysis = (result as Success<MatchAnalysis>).data;
    expect(analysis.professorId, 'p_001');
    expect(analysis.summary, contains('契合'));
    expect(analysis.strengths, isNotEmpty);
    expect(analysis.gaps, isNotEmpty);
    expect(analysis.suggestions, isNotEmpty);
    expect(llm.lastJsonMode, isTrue);
  });

  test('接地：prompt 含导师方向与学生已填字段，未填字段不出现', () async {
    final llm = _FakeLlm(Success(_validJson()));
    await AiMatchAnalysisRepository(llm).analyze(
      professor: _professor,
      profile: const UserProfile(name: '李四', researchInterests: ['医学影像']),
    );

    final userMessage = llm.lastMessages!.last.content;
    expect(userMessage, contains('医学影像'));
    expect(userMessage, contains('李四'));
    expect(userMessage.contains('highlights'), isFalse);
  });

  test('坏 JSON -> Failure(ServerException)', () async {
    final repo = AiMatchAnalysisRepository(_FakeLlm(const Success('not json')));

    final result = await repo.analyze(
      professor: _professor,
      profile: const UserProfile(),
    );

    expect((result as Failure<MatchAnalysis>).error, isA<ServerException>());
  });

  test('缺 summary -> Failure(ServerException)', () async {
    final repo = AiMatchAnalysisRepository(
      _FakeLlm(
        Success(jsonEncode({'strengths': [], 'gaps': [], 'suggestions': []})),
      ),
    );

    final result = await repo.analyze(
      professor: _professor,
      profile: const UserProfile(),
    );

    expect((result as Failure<MatchAnalysis>).error, isA<ServerException>());
  });

  test('LlmClient 失败透传', () async {
    final repo = AiMatchAnalysisRepository(
      _FakeLlm(const Failure(NetworkException())),
    );

    final result = await repo.analyze(
      professor: _professor,
      profile: const UserProfile(),
    );

    expect((result as Failure<MatchAnalysis>).error, isA<NetworkException>());
  });

  test('解析 dimensions：补齐为固定 5 轴并 clamp 分数', () async {
    final json = jsonEncode({
      'summary': '较契合。',
      'strengths': ['x'],
      'gaps': ['y'],
      'suggestions': ['z'],
      'dimensions': [
        {'label': '方向契合', 'score': 120, 'comment': '重合度高'},
        {'label': '地域', 'score': -5, 'comment': '需确认'},
      ],
    });
    final repo = AiMatchAnalysisRepository(_FakeLlm(Success(json)));

    final analysis =
        (await repo.analyze(
              professor: _professor,
              profile: const UserProfile(),
            )
            as Success<MatchAnalysis>)
            .data;

    final byLabel = {for (final d in analysis.dimensions) d.label: d};
    expect(analysis.dimensions, hasLength(5));
    expect(byLabel['方向契合']!.score, 100);
    expect(byLabel['地域']!.score, 0);
    expect(byLabel['方法匹配']!.comment, '信息不足');
  });

  test('无 dimensions 字段仍成功（退化为空）', () async {
    final repo = AiMatchAnalysisRepository(_FakeLlm(Success(_validJson())));
    final analysis =
        (await repo.analyze(
              professor: _professor,
              profile: const UserProfile(),
            )
            as Success<MatchAnalysis>)
            .data;
    expect(analysis.dimensions, isEmpty);
    expect(analysis.summary, isNotEmpty);
  });
}
