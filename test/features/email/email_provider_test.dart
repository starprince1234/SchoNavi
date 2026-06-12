import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/email_draft.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/outreach_email_repository.dart';
import 'package:scho_navi/features/email/providers/email_provider.dart';

class _FakeEmailRepo implements OutreachEmailRepository {
  _FakeEmailRepo(this.response);

  Future<Result<EmailDraft>> response;
  int calls = 0;
  Professor? lastProfessor;
  UserProfile? lastProfile;

  @override
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  }) {
    calls++;
    lastProfessor = professor;
    lastProfile = profile;
    return response;
  }
}

const _professor = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像'],
);
const _profile = UserProfile(name: '李四', degreeStage: '本科在读');

ProviderContainer _containerWith(OutreachEmailRepository repo) =>
    ProviderContainer(
      overrides: [outreachEmailRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  test('generate 成功 -> ready 且携带 draft + 透传入参', () async {
    final repo = _FakeEmailRepo(
      Future.value(const Success(EmailDraft(subject: 's', body: 'b'))),
    );
    final container = _containerWith(repo);
    addTearDown(container.dispose);

    await container
        .read(emailProvider.notifier)
        .generate(professor: _professor, profile: _profile);
    final state = container.read(emailProvider);

    expect(state.status, EmailStatus.ready);
    expect(state.draft?.subject, 's');
    expect(repo.lastProfessor?.id, 'p_001');
    expect(repo.lastProfile?.name, '李四');
  });

  test('generate 失败 -> error 且携带文案', () async {
    final container = _containerWith(
      _FakeEmailRepo(Future.value(const Failure(ServerException()))),
    );
    addTearDown(container.dispose);

    await container
        .read(emailProvider.notifier)
        .generate(professor: _professor, profile: _profile);
    final state = container.read(emailProvider);

    expect(state.status, EmailStatus.error);
    expect(state.message, '服务异常，请稍后重试');
  });

  test('generate 期间为 generating', () async {
    final completer = Completer<Result<EmailDraft>>();
    final container = _containerWith(_FakeEmailRepo(completer.future));
    addTearDown(container.dispose);

    final future = container
        .read(emailProvider.notifier)
        .generate(professor: _professor, profile: _profile);
    expect(container.read(emailProvider).status, EmailStatus.generating);

    completer.complete(const Success(EmailDraft(subject: 's', body: 'b')));
    await future;
    expect(container.read(emailProvider).status, EmailStatus.ready);
  });

  test('重新生成：再次调用仓储', () async {
    final repo = _FakeEmailRepo(
      Future.value(const Success(EmailDraft(subject: 's', body: 'b'))),
    );
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(emailProvider.notifier);

    await notifier.generate(professor: _professor, profile: _profile);
    await notifier.generate(professor: _professor, profile: _profile);

    expect(repo.calls, 2);
  });

  test('start 切换 professor 时重置为 idle', () async {
    final repo = _FakeEmailRepo(
      Future.value(const Success(EmailDraft(subject: 's', body: 'b'))),
    );
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(emailProvider.notifier);

    notifier.start('p_001');
    await notifier.generate(professor: _professor, profile: _profile);
    expect(container.read(emailProvider).status, EmailStatus.ready);

    notifier.start('p_002');
    expect(container.read(emailProvider).status, EmailStatus.idle);
    expect(container.read(emailProvider).draft, isNull);
  });
}
