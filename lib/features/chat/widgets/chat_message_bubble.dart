import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../domain/entities/recommendation.dart';
import '../../../shared/widgets/thinking_indicator.dart';
import 'recommendation_carousel.dart';

/// 单条对话气泡：用户右侧纯文本；助手左侧 Markdown；助手可嵌入横向滑动推荐卡片。
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.onTapRecommendation,
    this.onOpenHomepage,
    this.onRetryRecommendation,
    this.onRegenerate,
    this.onFeedback,
    this.onRerouteHome,
  });

  final ChatMessage message;
  final void Function(String professorId) onTapRecommendation;
  final void Function(Recommendation recommendation)? onOpenHomepage;
  final void Function(String messageId)? onRetryRecommendation;
  final void Function(String messageId)? onRegenerate;
  final void Function(String messageId, ChatMessageFeedback feedback)?
  onFeedback;
  final VoidCallback? onRerouteHome;

  @override
  Widget build(BuildContext context) {
    final isThinking =
        message.status == ChatMessageStatus.sending ||
        (message.status == ChatMessageStatus.streaming &&
            message.content.isEmpty);
    if (isThinking) {
      return const ThinkingIndicator();
    }

    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    final isError =
        message.status == ChatMessageStatus.error ||
        message.status == ChatMessageStatus.interrupted;
    final isStreaming = message.status == ChatMessageStatus.streaming;
    final bubbleColor = isUser
        ? scheme.primaryContainer
        : isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final maxWidth = math.min(360.0, MediaQuery.sizeOf(context).width * 0.78);

    final Widget body = (isUser || isError)
        ? Text(message.content)
        : GptMarkdown(message.content);
    final Widget content = isStreaming
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              body,
              const SizedBox(height: 6),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 6),
                  Text('生成中…', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          )
        : body;
    final Widget selectableContent = isUser
        ? content
        : SelectionArea(child: content);

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: selectableContent,
        ),
        if (message.relatedRecommendations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: RecommendationCarousel(
              key: ValueKey('recommendations-${message.id}'),
              recommendations: message.relatedRecommendations,
              onTap: onTapRecommendation,
              onOpenHomepage: onOpenHomepage,
            ),
          ),
        if (message.kind == ChatMessageKind.recommendation &&
            message.status == ChatMessageStatus.error &&
            onRetryRecommendation != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 6),
            child: FilledButton.icon(
              onPressed: () => onRetryRecommendation!(message.id),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试推荐'),
            ),
          ),
        if (_showActions)
          _MessageActions(
            message: message,
            onRegenerate: onRegenerate,
            onFeedback: onFeedback,
          ),
        if (message.kind == ChatMessageKind.forkReroute &&
            message.status == ChatMessageStatus.done &&
            onRerouteHome != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('继续问这位'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onRerouteHome,
                    child: const Text('回首页重挑 ›'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool get _showActions =>
      message.role == ChatRole.assistant &&
      message.kind == ChatMessageKind.conversation &&
      message.status == ChatMessageStatus.done &&
      (onRegenerate != null || onFeedback != null);
}

class _MessageActions extends StatelessWidget {
  const _MessageActions({
    required this.message,
    this.onRegenerate,
    this.onFeedback,
  });

  final ChatMessage message;
  final void Function(String messageId)? onRegenerate;
  final void Function(String messageId, ChatMessageFeedback feedback)?
  onFeedback;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = AppColors.inkSoft;
    final activeColor = AppColors.indigo;

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            tooltip: '复制',
            icon: Icons.copy_outlined,
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: message.content));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制')));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('复制失败')));
                }
              }
            },
          ),
          _ActionButton(
            tooltip: '重新生成',
            icon: Icons.refresh,
            onPressed: onRegenerate == null
                ? null
                : () => onRegenerate!(message.id),
          ),
          _ActionButton(
            tooltip: '有用',
            icon: message.feedback == ChatMessageFeedback.like
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            color: message.feedback == ChatMessageFeedback.like
                ? activeColor
                : inactiveColor,
            onPressed: onFeedback == null
                ? null
                : () => onFeedback!(
                    message.id,
                    message.feedback == ChatMessageFeedback.like
                        ? ChatMessageFeedback.none
                        : ChatMessageFeedback.like,
                  ),
          ),
          _ActionButton(
            tooltip: '没用',
            icon: message.feedback == ChatMessageFeedback.dislike
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            color: message.feedback == ChatMessageFeedback.dislike
                ? activeColor
                : inactiveColor,
            onPressed: onFeedback == null
                ? null
                : () => onFeedback!(
                    message.id,
                    message.feedback == ChatMessageFeedback.dislike
                        ? ChatMessageFeedback.none
                        : ChatMessageFeedback.dislike,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    this.color,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: color,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}
