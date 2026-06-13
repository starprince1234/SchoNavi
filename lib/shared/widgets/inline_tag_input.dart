import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/haptics/haptics.dart';

/// 标签占位符格式：{tagName}
final _tagPattern = RegExp(r'\{([^}]+)\}');

/// 用于在普通文本流中嵌入可删除标签的 [TextEditingController]。
///
/// 标签以 `{tagName}` 形式存储在 [text] 中，渲染时隐藏 `{` 和 `}`，
/// 只把标签名显示为普通文本；真正的 chip UI 由 [InlineTagInput]
/// 通过 [RenderEditable] 定位后覆盖在文本上方。
class InlineTagController extends TextEditingController {
  InlineTagController({super.text});

  /// 在当前光标位置插入一个标签占位符。
  void addTag(String tag) {
    final base = selection.baseOffset;
    final extent = selection.extentOffset;

    var start = selection.isValid && base >= 0 ? base : text.length;
    var end = selection.isValid && extent >= 0 ? extent : text.length;
    start = math.min(start, text.length).clamp(0, text.length);
    end = math.min(end, text.length).clamp(0, text.length);
    final normalizedStart = math.min(start, end);
    final normalizedEnd = math.max(start, end);

    final before = text.substring(0, normalizedStart);
    final after = text.substring(normalizedEnd);
    const open = '{';
    const close = '}';
    // 在标签后加一个空格，保证连续插入多个标签时不会贴在一起。
    final inserted = '$open$tag$close ';
    final newText = before + inserted + after;
    text = newText;
    selection = TextSelection.collapsed(
      offset: math.min(before.length + inserted.length, newText.length),
    );
  }

  /// 把带占位符的文本解码为普通 prompt（标签替换为空格分隔的文本）。
  String get plainText => text
      .replaceAllMapped(_tagPattern, (match) => ' ${match.group(1)} ')
      .replaceAll(RegExp(r' +'), ' ')
      .trim();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final children = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in _tagPattern.allMatches(text)) {
      // 标签之间至少保留一个空格，避免 chip 在视觉上重叠。
      final tagStart = match.start;
      final tagEnd = match.end;
      if (tagStart > lastEnd) {
        children.add(TextSpan(text: text.substring(lastEnd, tagStart), style: style));
      }
      children.add(
        TextSpan(
          children: [
            // 开始/结束标记占位但几乎不可见，只用于 RenderEditable 定位。
            // 额外加一个零宽空格，让 RenderEditable 给 chip 右侧留出间距。
            TextSpan(
              text: '{\u200B',
              style: style?.copyWith(color: Colors.transparent, fontSize: 0.01),
            ),
            TextSpan(text: match.group(1), style: style),
            TextSpan(
              text: '\u200B}',
              style: style?.copyWith(color: Colors.transparent, fontSize: 0.01),
            ),
          ],
        ),
      );
      lastEnd = tagEnd;
    }
    if (lastEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastEnd), style: style));
    }
    return TextSpan(children: children);
  }
}

/// 在 [TextField] 文本流中内联显示可删除标签的输入组件。
///
/// 底层是一个普通 [TextField]，标签以 `{tagName}` 占位符形式存在
/// 于文本中；组件通过 [RenderEditable.getBoxesForSelection] 计算
/// 每个标签名的精确位置，并在其上方覆盖一个真正的 chip widget。
class InlineTagInput extends StatefulWidget {
  const InlineTagInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.maxLines = 5,
    this.minLines = 1,
    this.maxLength,
    this.textInputAction = TextInputAction.newline,
    this.onSubmitted,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
  });

  final InlineTagController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsets contentPadding;

  @override
  State<InlineTagInput> createState() => _InlineTagInputState();
}

class _InlineTagInputState extends State<InlineTagInput> {
  final _fieldKey = GlobalKey();
  var _tagRects = <_TagRect>[];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleUpdate);
    widget.focusNode?.addListener(_scheduleUpdate);
  }

  @override
  void didUpdateWidget(covariant InlineTagInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleUpdate);
      widget.controller.addListener(_scheduleUpdate);
      _scheduleUpdate();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_scheduleUpdate);
      widget.focusNode?.addListener(_scheduleUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleUpdate);
    widget.focusNode?.removeListener(_scheduleUpdate);
    super.dispose();
  }

  void _scheduleUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateTagRects();
    });
  }

  void _updateTagRects() {
    final fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (fieldBox == null) return;

    final renderEditable = _findRenderEditable(fieldBox);
    if (renderEditable == null) return;

    final editableOffset = renderEditable.localToGlobal(Offset.zero);
    final fieldOffset = fieldBox.localToGlobal(Offset.zero);
    final delta = editableOffset - fieldOffset;

    final tags = <_TagRect>[];
    final text = widget.controller.text;
    for (final match in _tagPattern.allMatches(text)) {
      // 跳过 `{` 和 `}`，只取标签名区域，让 chip 左对齐标签名。
      final start = match.start + 1;
      final end = match.end - 1;
      final boxes = renderEditable.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
      if (boxes.isEmpty) continue;

      var rect = boxes.first.toRect();
      for (var i = 1; i < boxes.length; i++) {
        rect = rect.expandToInclude(boxes[i].toRect());
      }
      rect = rect.shift(delta);

      tags.add(
        _TagRect(
          tag: match.group(1)!,
          start: match.start,
          end: match.end,
          rect: rect,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _tagRects = tags);
  }

  RenderEditable? _findRenderEditable(RenderObject? node) {
    if (node == null) return null;
    if (node is RenderEditable) return node;
    RenderEditable? result;
    node.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  void _removeTagAt(_TagRect tagRect) {
    Haptics.light();
    final text = widget.controller.text;
    final newText = text.substring(0, tagRect.start) + text.substring(tagRect.end);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: tagRect.start),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextField(
          key: _fieldKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
            hoverColor: Colors.transparent,
            counterText: '',
            contentPadding: widget.contentPadding,
            hintText: widget.hintText,
          ),
        ),
        for (final tagRect in _tagRects)
          Positioned(
            left: tagRect.rect.left,
            top: tagRect.rect.top,
            child: _TagChip(
              tag: tagRect.tag,
              baselineHeight: tagRect.rect.height,
              onDeleted: () => _removeTagAt(tagRect),
            ),
          ),
      ],
    );
  }
}

class _TagRect {
  const _TagRect({
    required this.tag,
    required this.start,
    required this.end,
    required this.rect,
  });

  final String tag;
  final int start;
  final int end;
  final Rect rect;
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.baselineHeight,
    required this.onDeleted,
  });

  final String tag;
  final double baselineHeight;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = DefaultTextStyle.of(context).style;

    return Transform.translate(
      // 让 chip 垂直居中于文本基线。
      offset: Offset(0, -2),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {}, // chip 主体点击不拦截事件，仅显示。
          child: Container(
            height: baselineHeight + 6,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  tag,
                  style: textStyle.copyWith(
                    fontSize: (textStyle.fontSize ?? 14) - 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDeleted,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
