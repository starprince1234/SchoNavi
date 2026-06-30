import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics.dart';
import '../../../domain/entities/feedback.dart';

/// 场景内联反馈入口：点击带上下文跳到 /feedback。
class FeedbackEntryButton extends StatelessWidget {
  const FeedbackEntryButton({
    super.key,
    required this.type,
    this.route,
    this.sessionId,
    this.messageId,
    this.professorId,
    this.competitionId,
    this.prompt,
    this.label = '反馈',
    this.icon = Icons.feedback_outlined,
  });

  final FeedbackType type;
  final String? route;
  final String? sessionId;
  final String? messageId;
  final String? professorId;
  final String? competitionId;
  final String? prompt;
  final String label;
  final IconData icon;

  String get _typeQuery => switch (type) {
    FeedbackType.recommendation => 'recommendation',
    FeedbackType.missingProfessor => 'missing_professor',
    FeedbackType.bug => 'bug',
    FeedbackType.other => 'other',
  };

  void _open(BuildContext context) {
    Haptics.light();
    final q = <String, String>{
      'type': _typeQuery,
      'route': ?route,
      'sid': ?sessionId,
      'mid': ?messageId,
      'pid': ?professorId,
      'cid': ?competitionId,
      'prompt': ?prompt,
    };
    context.push(Uri(path: '/feedback', queryParameters: q).toString());
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      icon: Icon(icon),
      onPressed: () => _open(context),
    );
  }
}
