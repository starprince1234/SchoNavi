import 'chat_quick_actions.dart';

@Deprecated('Use ChatQuickActions. This wrapper keeps older callers compiling.')
class ChatQuickQuestions extends ChatQuickActions {
  const ChatQuickQuestions({
    super.key,
    required List<String> questions,
    required super.enabled,
    required super.onTap,
  }) : super(actions: questions);
}
