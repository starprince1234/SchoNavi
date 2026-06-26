import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bento_tile.dart';

const List<String> defaultChatQuickActions = ['解释理由', '换一批', '只看北京', '适合硕士'];

List<String> normalizeChatQuickActions(
  List<String> actions, {
  List<String> fallback = defaultChatQuickActions,
}) {
  final normalized = <String>[];
  final seen = <String>{};
  for (final action in actions) {
    final text = _normalizeAction(action);
    if (text == null || seen.contains(text)) continue;
    seen.add(text);
    normalized.add(text);
    if (normalized.length == 4) break;
  }
  if (normalized.isNotEmpty) return normalized;

  for (final action in fallback) {
    final text = _normalizeAction(action);
    if (text == null || seen.contains(text)) continue;
    seen.add(text);
    normalized.add(text);
    if (normalized.length == 4) break;
  }
  return normalized;
}

String? _normalizeAction(String value) {
  final text = value.trim().replaceAll(RegExp(r'[\s。.!！；;，,、]+$'), '').trim();
  if (text.isEmpty) return null;
  if (text.contains('?') || text.contains('？')) return null;
  if (text.runes.length > 8) return null;
  if (_questionLikePrefixes.any(text.startsWith)) return null;
  return text;
}

const List<String> _questionLikePrefixes = [
  '你',
  '是否',
  '请问',
  '能否',
  '除了',
  '有没有',
  '会不会',
  '能不能',
  '要不要',
];

/// 对话页底部的短操作横滑条。
///
/// 入参沿用 `followUpQuestions` 的数据通道，但 UI 只展示短操作 chip，
/// 如“换一批”“只看北京”。长问句会被过滤，避免挤压输入区或误导用户。
class ChatQuickActions extends StatelessWidget {
  const ChatQuickActions({
    super.key,
    required this.actions,
    required this.enabled,
    required this.onTap,
    this.fallback = defaultChatQuickActions,
  });

  final List<String> actions;
  final List<String> fallback;
  final bool enabled;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final displayActions = normalizeChatQuickActions(
      actions,
      fallback: fallback,
    );
    if (displayActions.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: displayActions.length,
        itemBuilder: (context, index) {
          final action = displayActions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: BentoTile(
                onTap: enabled
                    ? () {
                        Haptics.selection();
                        onTap(action);
                      }
                    : null,
                color: scheme.surfaceContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                borderRadius: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_outlined,
                      color: AppColors.coral,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
