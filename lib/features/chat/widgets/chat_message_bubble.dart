import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../domain/entities/chat_message.dart';
import '../../../shared/widgets/professor_card.dart';

/// 单条对话气泡：用户右侧纯文本；助手左侧 Markdown；助手可嵌入推荐卡片。
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.onTapRecommendation,
  });

  final ChatMessage message;
  final void Function(String professorId) onTapRecommendation;

  @override
  Widget build(BuildContext context) {
    if (message.status == ChatMessageStatus.sending) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('正在思考…'),
            ],
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    final isError = message.status == ChatMessageStatus.error;
    final bubbleColor = isUser
        ? scheme.primaryContainer
        : isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final maxWidth = math.min(360.0, MediaQuery.sizeOf(context).width * 0.78);

    final Widget content = (isUser || isError)
        ? Text(message.content)
        : GptMarkdown(message.content);

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
          child: content,
        ),
        for (final recommendation in message.relatedRecommendations)
          ProfessorCard(
            recommendation: recommendation,
            onTap: () => onTapRecommendation(recommendation.professorId),
          ),
      ],
    );
  }
}
