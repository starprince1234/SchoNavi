import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/haptics/haptics.dart';

const String _tagPlaceholder = '\uFFFC';
const int _tagPlaceholderCodeUnit = 0xFFFC;
final _legacyTagPattern = RegExp(r'\{([^}]+)\}');

/// 用于在普通文本流中嵌入可删除标签的 [TextEditingController]。
///
/// 每个标签在 [text] 中只占用一个 object replacement placeholder，
/// 标签名称由 controller 内部维护；渲染时通过 [WidgetSpan] 让 chip
/// 真实参与 Flutter 文本排版，避免换行后 overlay 定位错乱。
class InlineTagController extends TextEditingController {
  InlineTagController({String? text}) : super(text: '') {
    value = TextEditingValue(text: text ?? '');
  }

  final List<String> _tagLabels = <String>[];

  /// 在当前光标位置插入一个标签占位符。
  void addTag(String tag) {
    final label = tag.trim();
    if (label.isEmpty) return;

    final base = selection.baseOffset;
    final extent = selection.extentOffset;

    var start = selection.isValid && base >= 0 ? base : text.length;
    var end = selection.isValid && extent >= 0 ? extent : text.length;
    start = math.min(start, text.length).clamp(0, text.length);
    end = math.min(end, text.length).clamp(0, text.length);
    final normalizedStart = math.min(start, end);
    final normalizedEnd = math.max(start, end);

    final before = text.substring(0, normalizedStart);
    final selected = text.substring(normalizedStart, normalizedEnd);
    final after = text.substring(normalizedEnd);
    final beforeTagCount = _countTagPlaceholders(before);
    final selectedTagCount = _countTagPlaceholders(selected);
    final retainedAfterStart = beforeTagCount + selectedTagCount;

    // 在标签后加一个空格，保证连续插入多个标签时不会贴在一起。
    const inserted = '$_tagPlaceholder ';
    final newText = before + inserted + after;
    final newTags = <String>[
      ..._tagLabels.take(beforeTagCount),
      label,
      ..._tagLabels.skip(retainedAfterStart),
    ];

    _setValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: math.min(before.length + inserted.length, newText.length),
        ),
      ),
      newTags,
    );
  }

  /// 删除指定序号的标签。
  void removeTagAt(int tagIndex) {
    if (tagIndex < 0 || tagIndex >= _tagLabels.length) return;

    var currentTagIndex = 0;
    for (var offset = 0; offset < text.length; offset++) {
      if (text.codeUnitAt(offset) != _tagPlaceholderCodeUnit) continue;
      if (currentTagIndex != tagIndex) {
        currentTagIndex++;
        continue;
      }

      final newText = text.substring(0, offset) + text.substring(offset + 1);
      final newTags = List<String>.of(_tagLabels)..removeAt(tagIndex);
      _setValue(
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: math.min(offset, newText.length),
          ),
        ),
        newTags,
      );
      return;
    }
  }

  /// 把带占位符的文本解码为普通 prompt（标签替换为空格分隔的文本）。
  String get plainText {
    final buffer = StringBuffer();
    var tagIndex = 0;

    for (var offset = 0; offset < text.length; offset++) {
      if (text.codeUnitAt(offset) == _tagPlaceholderCodeUnit) {
        final label = tagIndex < _tagLabels.length ? _tagLabels[tagIndex] : '';
        if (label.isNotEmpty) {
          buffer
            ..write(' ')
            ..write(label)
            ..write(' ');
        }
        tagIndex++;
      } else {
        buffer.write(text.substring(offset, offset + 1));
      }
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  set value(TextEditingValue newValue) {
    final normalized = _normalizeIncomingValue(newValue);
    _setValue(normalized.value, normalized.tags);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final children = <InlineSpan>[];
    var runStart = 0;
    var tagIndex = 0;

    for (var offset = 0; offset < text.length; offset++) {
      if (text.codeUnitAt(offset) != _tagPlaceholderCodeUnit) continue;

      _addTextRun(
        children: children,
        start: runStart,
        end: offset,
        style: style,
        withComposing: withComposing,
      );

      final currentTagIndex = tagIndex;
      final label = tagIndex < _tagLabels.length ? _tagLabels[tagIndex] : '';
      children.add(
        WidgetSpan(
          alignment: ui.PlaceholderAlignment.middle,
          child: _InlineTagChip(
            tag: label,
            textStyle: style,
            onDeleted: () {
              Haptics.light();
              removeTagAt(currentTagIndex);
            },
          ),
        ),
      );
      tagIndex++;
      runStart = offset + 1;
    }

    _addTextRun(
      children: children,
      start: runStart,
      end: text.length,
      style: style,
      withComposing: withComposing,
    );

    return TextSpan(style: style, children: children);
  }

  void _addTextRun({
    required List<InlineSpan> children,
    required int start,
    required int end,
    required TextStyle? style,
    required bool withComposing,
  }) {
    if (start >= end) return;

    final composing = value.composing;
    final hasComposing =
        withComposing &&
        value.isComposingRangeValid &&
        composing.isValid &&
        composing.start < end &&
        composing.end > start;

    if (!hasComposing) {
      children.add(TextSpan(text: text.substring(start, end), style: style));
      return;
    }

    final composingStyle =
        style?.merge(const TextStyle(decoration: TextDecoration.underline)) ??
        const TextStyle(decoration: TextDecoration.underline);
    final composingStart = math.max(start, composing.start);
    final composingEnd = math.min(end, composing.end);

    if (start < composingStart) {
      children.add(
        TextSpan(text: text.substring(start, composingStart), style: style),
      );
    }
    if (composingStart < composingEnd) {
      children.add(
        TextSpan(
          text: text.substring(composingStart, composingEnd),
          style: composingStyle,
        ),
      );
    }
    if (composingEnd < end) {
      children.add(
        TextSpan(text: text.substring(composingEnd, end), style: style),
      );
    }
  }

  void _setValue(TextEditingValue newValue, List<String> tags) {
    _tagLabels
      ..clear()
      ..addAll(tags);
    super.value = newValue;
  }

  _NormalizedInlineValue _normalizeIncomingValue(TextEditingValue incoming) {
    final source = incoming.text;
    final offsetMap = List<int>.filled(source.length + 1, 0);
    final buffer = StringBuffer();
    final tags = <String>[];
    var sourceOffset = 0;
    var existingTagIndex = 0;

    while (sourceOffset < source.length) {
      offsetMap[sourceOffset] = buffer.length;

      final legacyMatch = _legacyTagPattern.matchAsPrefix(source, sourceOffset);
      if (legacyMatch != null) {
        final outputStart = buffer.length;
        buffer.write(_tagPlaceholder);
        tags.add(legacyMatch.group(1)!);
        final outputEnd = buffer.length;
        for (var i = sourceOffset; i <= legacyMatch.end; i++) {
          offsetMap[i] = i == sourceOffset ? outputStart : outputEnd;
        }
        sourceOffset = legacyMatch.end;
        continue;
      }

      if (source.codeUnitAt(sourceOffset) == _tagPlaceholderCodeUnit) {
        buffer.write(_tagPlaceholder);
        tags.add(
          existingTagIndex < _tagLabels.length
              ? _tagLabels[existingTagIndex]
              : '',
        );
        existingTagIndex++;
        sourceOffset++;
        offsetMap[sourceOffset] = buffer.length;
        continue;
      }

      buffer.write(source.substring(sourceOffset, sourceOffset + 1));
      sourceOffset++;
      offsetMap[sourceOffset] = buffer.length;
    }
    offsetMap[source.length] = buffer.length;

    return _NormalizedInlineValue(
      value: TextEditingValue(
        text: buffer.toString(),
        selection: _mapSelection(incoming.selection, offsetMap),
        composing: _mapTextRange(incoming.composing, offsetMap),
      ),
      tags: tags,
    );
  }

  TextSelection _mapSelection(TextSelection selection, List<int> offsetMap) {
    if (!selection.isValid) return selection;
    return TextSelection(
      baseOffset: _mapOffset(selection.baseOffset, offsetMap),
      extentOffset: _mapOffset(selection.extentOffset, offsetMap),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  TextRange _mapTextRange(TextRange range, List<int> offsetMap) {
    if (!range.isValid || range.isCollapsed) return TextRange.empty;
    final start = _mapOffset(range.start, offsetMap);
    final end = _mapOffset(range.end, offsetMap);
    if (start >= end) return TextRange.empty;
    return TextRange(start: start, end: end);
  }

  int _mapOffset(int offset, List<int> offsetMap) {
    if (offset < 0) return offset;
    if (offset >= offsetMap.length) return offsetMap.last;
    return offsetMap[offset];
  }

  static int _countTagPlaceholders(String value) {
    var count = 0;
    for (var offset = 0; offset < value.length; offset++) {
      if (value.codeUnitAt(offset) == _tagPlaceholderCodeUnit) count++;
    }
    return count;
  }
}

class _NormalizedInlineValue {
  const _NormalizedInlineValue({required this.value, required this.tags});

  final TextEditingValue value;
  final List<String> tags;
}

/// 在 [TextField] 文本流中内联显示可删除标签的输入组件。
///
/// 底层是普通 [TextField]；标签通过 [InlineTagController.buildTextSpan]
/// 生成 [WidgetSpan]，由原生文本布局处理换行与光标位置。
class InlineTagInput extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: textStyle,
      strutStyle: const StrutStyle(height: 1.6, forceStrutHeight: true),
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
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
        contentPadding: contentPadding,
        hintText: hintText,
      ),
    );
  }
}

class _InlineTagChip extends StatelessWidget {
  const _InlineTagChip({
    required this.tag,
    required this.textStyle,
    required this.onDeleted,
  });

  final String tag;
  final TextStyle? textStyle;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveTextStyle = textStyle ?? DefaultTextStyle.of(context).style;

    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 1),
      child: Material(
        key: const ValueKey('inline-tag-chip'),
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 24,
          child: Padding(
            padding: const EdgeInsets.only(left: 7, right: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: effectiveTextStyle.copyWith(
                      fontSize: (effectiveTextStyle.fontSize ?? 14) - 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 1),
                Semantics(
                  button: true,
                  label: '删除$tag',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDeleted,
                    child: SizedBox(
                      width: 19,
                      height: 19,
                      child: Icon(
                        Icons.close,
                        size: 13,
                        color: scheme.onSurfaceVariant,
                      ),
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
