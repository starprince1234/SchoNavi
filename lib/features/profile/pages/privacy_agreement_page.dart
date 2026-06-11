import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../shared/widgets/bento_tile.dart';

class PrivacyAgreementPage extends ConsumerStatefulWidget {
  const PrivacyAgreementPage({super.key});

  @override
  ConsumerState<PrivacyAgreementPage> createState() => _PrivacyAgreementPageState();
}

class _PrivacyAgreementPageState extends ConsumerState<PrivacyAgreementPage> {
  bool _agreed = false;

  static const String _privacyAgreedKey = 'privacy_agreed';

  Future<void> _onAgree() async {
    if (!_agreed) return;
    Haptics.medium();
    final store = ref.read(localStoreProvider);
    await store.setBool(_privacyAgreedKey, true);
    if (!mounted) return;
    context.push('/profile/intro');
  }

  void _onDisagree() {
    Haptics.light();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('隐私协议')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我们尊重你的隐私。在使用个人档案功能前，请阅读以下协议：',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BentoTile(
                  color: scheme.surfaceContainerLowest,
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          icon: Icons.description_outlined,
                          title: '收集的信息',
                          content: '姓名、性别、学校、专业、GPA、研究兴趣、竞赛成果、科研成果',
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                        const Divider(height: 24),
                        _buildSection(
                          icon: Icons.track_changes_outlined,
                          title: '使用目的',
                          content: '• 个性化导师推荐\n• 生成 outreach 邮件\n• 匹配度分析',
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                        const Divider(height: 24),
                        _buildSection(
                          icon: Icons.sync_outlined,
                          title: '数据处理方式',
                          content: '本地存储 + 发送给大模型解析',
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                        const Divider(height: 24),
                        _buildSection(
                          icon: Icons.verified_user_outlined,
                          title: '你的权利',
                          content: '随时在「我的档案」中修改或删除数据',
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('我已阅读并同意隐私协议'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _agreed ? _onAgree : null,
                  child: const Text('同意并继续'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _onDisagree,
                  child: const Text('不同意，返回'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(color: scheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
