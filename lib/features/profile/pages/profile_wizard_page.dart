import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/user_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/achievements_editor.dart';
import '../widgets/basic_info_form.dart';
import '../widgets/score_and_interests_form.dart';
import '../widgets/wizard_scaffold.dart';

/// 首填向导：3 步，每步「下一步」渐进落盘，末步「完成」→ /profile。
class ProfileWizardPage extends ConsumerStatefulWidget {
  const ProfileWizardPage({super.key});

  @override
  ConsumerState<ProfileWizardPage> createState() => _ProfileWizardPageState();
}

class _ProfileWizardPageState extends ConsumerState<ProfileWizardPage> {
  int _step = 0;
  late UserProfile _draft = ref.read(profileProvider);

  Future<void> _persist() => ref.read(profileProvider.notifier).save(_draft);

  Future<void> _next() async {
    await _persist();
    if (_step < 2) {
      setState(() => _step++);
    } else if (mounted) {
      context.go('/profile');
    }
  }

  void _back() => setState(() => _step--);

  @override
  Widget build(BuildContext context) {
    final (title, child) = switch (_step) {
      0 => (
        '基本信息',
        Column(
          children: [
            BasicInfoForm(
              value: _draft,
              onChanged: (p) => setState(() => _draft = p),
            ),
            const SizedBox(height: 16),
            Text(
              '你的资料将随请求发送给大模型，用于解析与个性化推荐、套磁和匹配分析。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      1 => (
        '成绩 & 方向',
        ScoreAndInterestsForm(
          value: _draft,
          onChanged: (p) => setState(() => _draft = p),
        ),
      ),
      _ => (
        '成果',
        AchievementsEditor(
          value: _draft,
          onChanged: (p) => setState(() => _draft = p),
        ),
      ),
    };

    return WizardScaffold(
      title: title,
      index: _step,
      count: 3,
      onBack: _step == 0 ? null : _back,
      onNext: _next,
      nextLabel: _step == 2 ? '完成' : '下一步',
      child: child,
    );
  }
}
