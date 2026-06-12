import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_outreach_email_repository.dart';
import 'package:scho_navi/domain/entities/email_draft.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

const _professor = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
);

void main() {
  test('默认无模型配置时不硬编码邮件内容，返回配置错误', () async {
    final repo = MockOutreachEmailRepository();

    final result = await repo.generate(
      professor: _professor,
      profile: const UserProfile(name: '李四', degreeStage: '本科在读'),
    );

    expect(
      (result as Failure<EmailDraft>).error,
      isA<MissingLlmConfigurationException>(),
    );
  });

  test('学生信息缺失也不会生成模板草稿', () async {
    final repo = MockOutreachEmailRepository();

    final result = await repo.generate(
      professor: _professor,
      profile: const UserProfile(),
    );

    expect(result, isA<Failure<EmailDraft>>());
  });
}
