import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/haptics/haptics.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/widgets/section_header.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('个人'),
          ),
          ListTile(
            key: const Key('settings-profile-entry'),
            leading: const Icon(Icons.person_outline),
            title: const Text('我的背景档案'),
            subtitle: const Text('用于让推荐结合你的成绩 / 竞赛 / 科研'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Haptics.light();
              context.push('/profile');
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('隐私'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(
              cfg.dataSource == DataSource.http ? '删除远端资料' : '清除本地数据',
            ),
            subtitle: Text(
              cfg.dataSource == DataSource.http
                  ? '请求后端删除收藏 / 历史 / 个人背景，并清除本机匿名凭证'
                  : '收藏 / 历史 / 个人背景（仅本机）',
            ),
            onTap: () {
              Haptics.light();
              _confirmClear(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('数据如何使用'),
            subtitle: Text(
              cfg.dataSource == DataSource.http
                  ? '真实后端模式下，档案 / 收藏 / 历史会同步到后端；推荐、匹配和套磁请求会发送必要资料。'
                  : '资料仅保存在本机；LLM 模式下会随请求发送给大模型用于解析与推荐。',
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('关于'),
          ),
          ListTile(title: const Text('版本'), subtitle: Text(cfg.appVersion)),
          const ListTile(
            title: Text('SchoNavi'),
            subtitle: Text('用自然语言找到适合你的导师（AIGC 选导师助手）'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final remote = ref.read(appConfigProvider).dataSource == DataSource.http;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(remote ? '删除远端资料' : '清除本地数据'),
        content: Text(
          remote
              ? '将请求后端删除当前身份下的收藏、历史与个人背景，并清除本机匿名凭证。是否继续？'
              : '将清除本机的收藏、历史与个人背景，且不可恢复。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Haptics.light();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Haptics.light();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final favoriteRepo = ref.read(favoriteRepositoryProvider);
      for (final item in favoriteRepo.list()) {
        await favoriteRepo.remove(item.professorId);
      }
      await ref.read(historyRepositoryProvider).clear();
      await ref.read(profileRepositoryProvider).clear();
      if (remote) await ref.read(apiAuthenticatorProvider).clear();
      ref.invalidate(favoritesProvider);
      ref.invalidate(searchHistoryProvider);
      ref.invalidate(profileProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(remote ? '已删除远端资料' : '已清除本地数据')),
      );
    } catch (error) {
      final message = error is AppException ? error.message : '清除失败，请稍后重试';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
