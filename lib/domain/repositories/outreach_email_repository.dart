import '../../core/result/result.dart';
import '../entities/email_draft.dart';
import '../entities/professor.dart';
import '../entities/user_profile.dart';

/// 套磁邮件生成。
abstract interface class OutreachEmailRepository {
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  });
}
