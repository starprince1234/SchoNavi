import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/email_draft.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/outreach_email_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/email/pages/email_page.dart';

const _professor = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像'],
);

class _FakeProfessorRepo implements ProfessorRepository {
  @override
  Future<Result<Professor>> getProfessor(String professorId) async =>
      const Success(_professor);
}

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo(this._profile);

  UserProfile _profile;
  int saves = 0;

  @override
  UserProfile load() => _profile;

  @override
  Future<void> save(UserProfile profile) async {
    saves++;
    _profile = profile;
  }

  @override
  Future<void> clear() async {}
}

class _FakeEmailRepo implements OutreachEmailRepository {
  _FakeEmailRepo(this.draft);

  final EmailDraft draft;

  @override
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  }) async => Success(draft);
}

Widget _wrap(_FakeProfileRepo profileRepo, _FakeEmailRepo emailRepo) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const EmailPage(professorId: 'p_001'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      professorRepositoryProvider.overrideWithValue(_FakeProfessorRepo()),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      outreachEmailRepositoryProvider.overrideWithValue(emailRepo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'Clipboard.setData') {
            final data = methodCall.arguments as Map<dynamic, dynamic>;
            clipboardText = data['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('生成后显示可编辑主题与正文', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final emailRepo = _FakeEmailRepo(
      const EmailDraft(subject: '测试主题', body: '正文内容：尊敬的张三教授…'),
    );
    await tester.pumpWidget(_wrap(profileRepo, emailRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('生成套磁邮件'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '测试主题'), findsOneWidget);
    expect(find.widgetWithText(TextField, '正文内容：尊敬的张三教授…'), findsOneWidget);
  });

  testWidgets('复制：点击后提示已复制', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final emailRepo = _FakeEmailRepo(
      const EmailDraft(subject: '主题', body: '正文'),
    );
    await tester.pumpWidget(_wrap(profileRepo, emailRepo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成套磁邮件'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('复制'));
    await tester.pump();

    expect(find.text('已复制到剪贴板'), findsOneWidget);
    expect(clipboardText, '主题\n\n正文');
  });

  testWidgets('保存背景：导航到 /profile', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final emailRepo = _FakeEmailRepo(
      const EmailDraft(subject: '主题', body: '正文'),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const EmailPage(professorId: 'p_001'),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const Text('profile-marker')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          professorRepositoryProvider.overrideWithValue(_FakeProfessorRepo()),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          outreachEmailRepositoryProvider.overrideWithValue(emailRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成套磁邮件'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存背景'));
    await tester.pumpAndSettle();

    expect(find.text('profile-marker'), findsOneWidget);
  });
}
