import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../shared/widgets/section_header.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appConfigProvider);
    final configured = cfg.llm.isConfigured;

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
            child: SectionHeader('数据源'),
          ),
          ListTile(
            key: const Key('settings-data-source'),
            leading: const Icon(Icons.hub_outlined),
            title: const Text('当前模式'),
            subtitle: Text(
              switch (cfg.dataSource) {
                DataSource.llm => configured
                    ? 'LLM 模式：推荐、解析与排序由大模型完成'
                    : 'LLM 模式：未配置 LLM_API_KEY，请在构建时传入后重试',
                DataSource.http => '真实后端模式：HTTP 仓储待接入',
              },
            ),
          ),
          ListTile(
            title: const Text('当前模型'),
            subtitle: Text(configured ? cfg.llm.model : '—'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('演示'),
          ),
          SwitchListTile(
            key: const Key('settings-demo-switch'),
            title: const Text('演示模式'),
            subtitle: const Text('在推荐结果页展示本次 AI 调用的 prompt 与原始返回'),
            value: cfg.featureFlags.showAiTrace,
            onChanged: (on) {
              Haptics.light();
              ref.read(appConfigProvider.notifier).setShowAiTrace(on);
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SectionHeader('隐私'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清除本地数据'),
            subtitle: const Text('收藏 / 历史 / 个人背景（仅本机）'),
            onTap: () {
              Haptics.light();
              _confirmClear(context, ref);
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('数据如何使用'),
            subtitle: Text('资料仅保存在本机；LLM 模式下会随请求发送给大模型用于解析与推荐。'),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除本地数据'),
        content: const Text('将清除本机的收藏、历史与个人背景，且不可恢复。是否继续？'),
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

    final favoriteRepo = ref.read(favoriteRepositoryProvider);
    for (final item in favoriteRepo.list()) {
      await favoriteRepo.remove(item.professorId);
    }
    await ref.read(historyRepositoryProvider).clear();
    await ref.read(profileRepositoryProvider).clear();
    messenger.showSnackBar(const SnackBar(content: Text('已清除本地数据')));
  }
}
