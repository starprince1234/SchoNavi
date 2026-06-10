import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/professor.dart';
import '../../../features/professor/providers/professor_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../providers/email_provider.dart';
import '../widgets/profile_sheet.dart';

class EmailPage extends ConsumerStatefulWidget {
  const EmailPage({super.key, required this.professorId});

  final String professorId;

  @override
  ConsumerState<EmailPage> createState() => _EmailPageState();
}

class _EmailPageState extends ConsumerState<EmailPage> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(emailProvider.notifier).start(widget.professorId);
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _generate(Professor professor) async {
    var profile = ref.read(profileRepositoryProvider).load();
    if (profile.isEmpty) {
      final edited = await showProfileSheet(context, profile);
      if (edited == null) return;
      await ref.read(profileRepositoryProvider).save(edited);
      profile = edited;
    }
    await ref
        .read(emailProvider.notifier)
        .generate(professor: professor, profile: profile);
  }

  Future<void> _saveBackground() async {
    final current = ref.read(profileRepositoryProvider).load();
    final edited = await showProfileSheet(context, current);
    if (edited == null) return;
    await ref.read(profileRepositoryProvider).save(edited);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存个人背景')));
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(
        text: '${_subjectController.text}\n\n${_bodyController.text}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<EmailState>(emailProvider, (previous, next) {
      if (next.status == EmailStatus.ready && next.draft != null) {
        _subjectController.text = next.draft!.subject;
        _bodyController.text = next.draft!.body;
      }
    });

    final professorAsync = ref.watch(professorProvider(widget.professorId));
    final email = ref.watch(emailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('套磁邮件')),
      body: professorAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is AppException ? error.message : '出错了，请稍后重试',
          onRetry: () => ref.invalidate(professorProvider(widget.professorId)),
        ),
        data: (professor) => _buildBody(professor, email),
      ),
    );
  }

  Widget _buildBody(Professor professor, EmailState email) {
    return switch (email.status) {
      EmailStatus.idle => _IdlePrompt(
        professor: professor,
        onGenerate: () => _generate(professor),
      ),
      EmailStatus.generating => const LoadingView(),
      EmailStatus.error => ErrorView(
        message: email.message ?? '生成失败，请重试',
        onRetry: () => _generate(professor),
      ),
      EmailStatus.ready => _DraftForm(
        subjectController: _subjectController,
        bodyController: _bodyController,
        onCopy: _copy,
        onRegenerate: () => _generate(professor),
        onSaveBackground: _saveBackground,
      ),
    };
  }
}

class _IdlePrompt extends StatelessWidget {
  const _IdlePrompt({required this.professor, required this.onGenerate});

  final Professor professor;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              '为 ${professor.name}${professor.title} 生成一封个性化套磁邮件草稿',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '将结合导师研究方向与你的背景生成可编辑、可复制的中文邮件。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('生成套磁邮件'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftForm extends StatelessWidget {
  const _DraftForm({
    required this.subjectController,
    required this.bodyController,
    required this.onCopy,
    required this.onRegenerate,
    required this.onSaveBackground,
  });

  final TextEditingController subjectController;
  final TextEditingController bodyController;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final VoidCallback onSaveBackground;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('主题', style: textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: subjectController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),
        Text('正文', style: textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: bodyController,
          minLines: 8,
          maxLines: 20,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
              label: const Text('复制'),
            ),
            OutlinedButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('重新生成'),
            ),
            TextButton.icon(
              onPressed: onSaveBackground,
              icon: const Icon(Icons.person_outline),
              label: const Text('保存背景'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '提示：邮件为 AI 生成草稿，请核对事实后再发送。',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
