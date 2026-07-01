import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/professor.dart';
import '../../../features/professor/providers/professor_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../core/haptics/haptics.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bento_action_tile.dart';
import '../../../shared/widgets/bento_grid.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/email_provider.dart';

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
    final profile = ref.read(profileProvider);
    if (profile.isEmpty) {
      final store = ref.read(localStoreProvider);
      final agreed = store.getBool('privacy_agreed') ?? false;
      if (!agreed) {
        context.push('/profile/privacy');
      } else {
        context.push('/profile/intro');
      }
      return;
    }
    await ref
        .read(emailProvider.notifier)
        .generate(professor: professor, profile: profile);
  }

  Future<void> _saveBackground() async {
    context.push('/profile');
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(
        text: '${_subjectController.text}\n\n${_bodyController.text}',
      ),
    );
    Haptics.success();
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BentoTile(
          color: scheme.surfaceContainerLowest,
          width: double.infinity,
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
      ),
    );
  }
}

class _DraftForm extends StatefulWidget {
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
  State<_DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<_DraftForm> {
  bool _copied = false;
  Timer? _copyTimer;

  void _handleCopy() {
    widget.onCopy();
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedEntrance(
          index: 0,
          child: BentoTile(
            color: scheme.surfaceContainerLowest,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('主题', style: textTheme.titleSmall),
                const SizedBox(height: 6),
                TextField(
                  controller: widget.subjectController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedEntrance(
          index: 1,
          child: BentoTile(
            color: scheme.surfaceContainerLowest,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('正文', style: textTheme.titleSmall),
                const SizedBox(height: 6),
                TextField(
                  controller: widget.bodyController,
                  minLines: 8,
                  maxLines: 20,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedEntrance(
          index: 2,
          child: BentoGrid(
            crossAxisCount: 3,
            spacing: 8,
            animateEntrance: false,
            children: [
              BentoTile(
                onTap: _handleCopy,
                height: 88,
                color: scheme.surfaceContainerLowest,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _copied ? Icons.check : Icons.copy,
                          key: ValueKey<bool>(_copied),
                          size: 32,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_copied ? '已复制' : '复制', style: textTheme.titleSmall),
                    ],
                  ),
                ),
              ),
              BentoActionTile(
                icon: Icons.refresh,
                label: '重新生成',
                onTap: widget.onRegenerate,
              ),
              BentoActionTile(
                icon: Icons.person_outline,
                label: '保存背景',
                onTap: widget.onSaveBackground,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('提示：邮件为 AI 生成草稿，请核对事实后再发送。', style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
