import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/email_draft.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/outreach_email_repository.dart';

/// 无模型配置时的占位实现：不硬编码邮件正文，提示用户配置 LLM。
class MockOutreachEmailRepository implements OutreachEmailRepository {
  @override
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  }) async => const Failure(MissingLlmConfigurationException());
}
