import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_surface.dart';

/// 对话页底部的输入条：外层 [AnimatedContainer] 画圆角聚焦边框，内层
/// [TextField] 显式置空全部边框状态（避免主题 `focusedBorder` 叠加渲染出
/// 双重方框）。
///
/// 从 `ChatPage` 的私有 `_InputBar` 提取为公共 widget。`/chat` 路由沿用
/// `TextEditingController` 版；首页原地对话为保留标签输入能力，继续用
/// `InlineTagInput`，不复用本组件。
///
/// [isNewSession] 控制提示文案：新会话「继续描述你的需求…」，追问会话
/// 「输入你的追问…」，对齐 ChatGPT App 新对话页措辞。
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.canStop,
    required this.onSubmit,
    required this.onStop,
    this.isNewSession = false,
  });

  final TextEditingController controller;
  final bool isBusy;
  final bool canStop;
  final void Function(String) onSubmit;
  final VoidCallback onStop;
  final bool isNewSession;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit => widget.controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focusBorder = Border.all(
      color: _focused
          ? AppColors.indigo
          : scheme.outline.withValues(alpha: 0.4),
      width: _focused ? 2 : 1,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GlassSurface(
          frosted: true,
          radius: 24,
          padding: EdgeInsets.zero,
          border: focusBorder,
          shadow: AppColors.shadowElevated,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: !widget.isBusy,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: widget.isBusy ? null : widget.onSubmit,
                  decoration: InputDecoration(
                    // 显式置空所有边框状态：外层 AnimatedContainer 已画圆角边框，
                    // 若只设 `border` 而漏掉 enabled/focused 等，主题
                    // `InputDecorationTheme.focusedBorder`（2px coral
                    // OutlineInputBorder）会在聚焦时叠加渲染，出现双重方框。
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintText: widget.isNewSession ? '继续描述你的需求…' : '输入你的追问…',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: widget.canStop
                    ? Tooltip(
                        message: '停止生成',
                        child: Material(
                          color: AppColors.indigo,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: widget.onStop,
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.stop,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      )
                    : widget.isBusy
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Tooltip(
                        message: '发送',
                        child: Material(
                          color: _canSubmit
                              ? AppColors.indigo
                              : scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _canSubmit
                                ? () {
                                    Haptics.medium();
                                    widget.onSubmit(widget.controller.text);
                                  }
                                : null,
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.arrow_upward,
                                color: _canSubmit
                                    ? Colors.white
                                    : AppColors.inkSoft,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
