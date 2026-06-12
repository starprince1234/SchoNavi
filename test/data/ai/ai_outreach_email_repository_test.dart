import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_outreach_email_repository.dart';
import 'package:scho_navi/domain/entities/email_draft.dart';
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
  }) => throw UnimplementedError();
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

void main() {
  test('解析 {subject, body} 且使用 JSON 模式', () async {
    final llm = _FakeLlm(
      Success(jsonEncode({'subject': '套磁-医学影像', 'body': '尊敬的张三教授：……'})),
    );
    final repo = AiOutreachEmailRepository(llm);

    final result = await repo.generate(
      professor: _professor,
      profile: const UserProfile(name: '李四', degreeStage: '本科在读'),
    );

    final draft = (result as Success<EmailDraft>).data;
    expect(draft.subject, '套磁-医学影像');
    expect(draft.body, contains('张三'));
    expect(llm.lastJsonMode, isTrue);
  });

  test('接地：user prompt 含导师方向，且不含未提供的学生字段', () async {
    final llm = _FakeLlm(Success(jsonEncode({'subject': 's', 'body': 'b'})));
    final repo = AiOutreachEmailRepository(llm);

    await repo.generate(
      professor: _professor,
      profile: const UserProfile(name: '李四'),
    );

    final userMessage = llm.lastMessages!.last.content;
    expect(userMessage, contains('医学影像'));
    expect(userMessage, contains('李四'));
    expect(userMessage.contains('highlights'), isFalse);
  });

  test('坏 JSON -> Failure(ServerException)', () async {
    final repo = AiOutreachEmailRepository(_FakeLlm(const Success('not json')));

    final result = await repo.generate(
      professor: _professor,
      profile: const UserProfile(),
    );

    expect((result as Failure<EmailDraft>).error, isA<ServerException>());
  });

  test('缺字段 JSON -> Failure(ServerException)', () async {
    final repo = AiOutreachEmailRepository(
      _FakeLlm(const Success('{"subject":"只有主题"}')),
    );

    final result = await repo.generate(
      professor: _professor,
      profile: const UserProfile(),
    );

    expect((result as Failure<EmailDraft>).error, isA<ServerException>());
  });

  test('LlmClient 失败透传', () async {
    final repo = AiOutreachEmailRepository(
      _FakeLlm(const Failure(NetworkException())),
    );

    final result = await repo.generate(
      professor: _professor,
      profile: const UserProfile(),
    );

    expect((result as Failure<EmailDraft>).error, isA<NetworkException>());
  });
}
