import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/email_draft.dart';
import '../../../domain/entities/professor.dart';
import '../../../domain/entities/user_profile.dart';

enum EmailStatus { idle, generating, ready, error }

/// 套磁邮件页状态。单屏一次一封，用 start 注入导师并在切换时重置。
class EmailState {
  const EmailState({
    required this.professorId,
    required this.status,
    this.draft,
    this.message,
  });

  const EmailState.initial()
    : professorId = null,
      status = EmailStatus.idle,
      draft = null,
      message = null;

  final String? professorId;
  final EmailStatus status;
  final EmailDraft? draft;
  final String? message;
}

class EmailNotifier extends Notifier<EmailState> {
  @override
  EmailState build() => const EmailState.initial();

  void start(String professorId) {
    if (state.professorId == professorId) return;
    state = EmailState(professorId: professorId, status: EmailStatus.idle);
  }

  Future<void> generate({
    required Professor professor,
    required UserProfile profile,
  }) async {
    final professorId = state.professorId ?? professor.id;
    state = EmailState(
      professorId: professorId,
      status: EmailStatus.generating,
    );

    final result = await ref
        .read(outreachEmailRepositoryProvider)
        .generate(professor: professor, profile: profile);

    state = switch (result) {
      Success(:final data) => EmailState(
        professorId: professorId,
        status: EmailStatus.ready,
        draft: data,
      ),
      Failure(:final error) => EmailState(
        professorId: professorId,
        status: EmailStatus.error,
        message: error.message,
      ),
    };
  }
}

final emailProvider = NotifierProvider<EmailNotifier, EmailState>(
  EmailNotifier.new,
);
