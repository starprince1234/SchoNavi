import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/email_draft.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/outreach_email_repository.dart';

/// 用大模型据【导师】+【学生背景】生成套磁邮件 JSON。
class AiOutreachEmailRepository implements OutreachEmailRepository {
  AiOutreachEmailRepository(this.llm);

  final LlmClient llm;

  @override
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  }) async {
    final result = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(professor, profile)),
      ],
      jsonMode: true,
    );
    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final data) => _parseDraft(data),
    };
  }

  Result<EmailDraft> _parseDraft(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(ServerException());
      }
      final subject = (decoded['subject'] as String?)?.trim();
      final body = (decoded['body'] as String?)?.trim();
      if (subject == null ||
          subject.isEmpty ||
          body == null ||
          body.isEmpty) {
        return const Failure(ServerException());
      }
      return Success(EmailDraft(subject: subject, body: body));
    } catch (_) {
      return const Failure(ServerException());
    }
  }

  String _userPrompt(Professor professor, UserProfile profile) {
    final professorFacts = <String, Object?>{
      'name': professor.name,
      'title': professor.title,
      'university': professor.university,
      'college': professor.college,
      'researchFields': professor.researchFields,
      if (professor.bio != null) 'bio': professor.bio,
    };
    final studentFacts = <String, Object?>{
      if (profile.name != null) 'name': profile.name,
      if (profile.degreeStage != null) 'degreeStage': profile.degreeStage,
      if (profile.school != null) 'school': profile.school,
      if (profile.major != null) 'major': profile.major,
      if (profile.researchInterests.isNotEmpty)
        'researchInterests': profile.researchInterests,
      if (profile.highlights != null) 'highlights': profile.highlights,
    };
    return '【导师】${jsonEncode(professorFacts)}\n'
        '【学生背景】${jsonEncode(studentFacts)}';
  }

  static const String _systemPrompt = '''
你是帮学生撰写套磁邮件的助手。根据【导师】与【学生背景】生成一封中文邮件，仅输出一个 JSON 对象 {"subject","body"}，不要 Markdown 或多余文字。
规则：
1. 礼貌、专业，正文 200-350 字。
2. 正文结构：自我介绍 -> 为何对该导师方向感兴趣（结合其研究方向）-> 自身相关基础（只用【学生背景】提供的信息，不得编造成果、奖项、绩点或经历）-> 请求（了解招生 / 读研读博机会）-> 礼貌结尾。
3. 称呼用导师姓名 + 职称（如"张三教授"）。
4. 不要编造导师或学生的任何事实；学生信息缺失就不提，不要写虚构占位。
5. subject 为简洁的邮件主题（含意向与方向）。
''';
}
