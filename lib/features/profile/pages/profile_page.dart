import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_bottom_sheet.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../providers/profile_provider.dart';
import '../widgets/achievements_editor.dart';
import '../widgets/basic_info_form.dart';
import '../widgets/profile_section_tile.dart';
import '../widgets/profile_summary_header.dart';
import '../widgets/score_and_interests_form.dart';

/// 档案中心：完成度头 + 分区卡（点开聚焦编辑，复用向导 organism）。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的档案')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedEntrance(
            index: 0,
            child: ProfileSummaryHeader(
              profile: profile,
              onUseForReco: () => context.go('/home'),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedEntrance(
            index: 1,
            child: ProfileSectionTile(
              title: '基本信息',
              summary: profile.name ?? '待填写',
              done: profile.name != null && profile.gender != null,
              onTap: () => _editBasic(context, ref, profile),
            ),
          ),
          AnimatedEntrance(
            index: 2,
            child: ProfileSectionTile(
              title: '成绩 & 方向',
              summary: profile.score?.gpa != null ? 'GPA ${profile.score!.gpa}' : '待填写',
              done: profile.score?.gpa != null,
              onTap: () => _editScore(context, ref, profile),
            ),
          ),
          AnimatedEntrance(
            index: 3,
            child: ProfileSectionTile(
              title: '竞赛成果',
              summary: '${profile.competitions.length} 项',
              done: profile.competitions.isNotEmpty,
              onTap: () => _editAchievements(context, ref, profile),
            ),
          ),
          AnimatedEntrance(
            index: 4,
            child: ProfileSectionTile(
              title: '科研成果',
              summary: '${profile.research.length} 项',
              done: profile.research.isNotEmpty,
              onTap: () => _editAchievements(context, ref, profile),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBasic(BuildContext context, WidgetRef ref, UserProfile p) =>
      _editSheet(context, ref, p, (draft, onChanged) => BasicInfoForm(value: draft, onChanged: onChanged));

  Future<void> _editScore(BuildContext context, WidgetRef ref, UserProfile p) =>
      _editSheet(context, ref, p, (draft, onChanged) => ScoreAndInterestsForm(value: draft, onChanged: onChanged));

  Future<void> _editAchievements(BuildContext context, WidgetRef ref, UserProfile p) =>
      _editSheet(context, ref, p, (draft, onChanged) => AchievementsEditor(value: draft, onChanged: onChanged));

  Future<void> _editSheet(
    BuildContext context,
    WidgetRef ref,
    UserProfile initial,
    Widget Function(UserProfile draft, ValueChanged<UserProfile> onChanged) builder,
  ) async {
    var draft = initial;
    await showAppBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                builder(draft, (p) => setState(() => draft = p)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('保存'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
    await ref.read(profileProvider.notifier).save(draft);
  }
}
