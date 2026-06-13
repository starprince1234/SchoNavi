import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/inline_tag_input.dart';

void main() {
  group('InlineTagController', () {
    test('addTag 在空文本末尾插入标签', () {
      final controller = InlineTagController();
      controller.addTag('人工智能');

      expect(controller.text, '{人工智能} ');
      expect(controller.plainText.trim(), '人工智能');
    });

    test('addTag 在光标位置插入标签', () {
      final controller = InlineTagController(text: '我想要导师');
      controller.selection = const TextSelection.collapsed(offset: 3);
      controller.addTag('人工智能');

      expect(controller.text, '我想要{人工智能} 导师');
      expect(controller.plainText.trim(), '我想要 人工智能 导师');
    });

    test('addTag 在无效 selection 时不崩溃，默认插到末尾', () {
      final controller = InlineTagController(text: '我想要');
      controller.selection = const TextSelection.collapsed(offset: -1);
      controller.addTag('人工智能');

      expect(controller.text, '我想要{人工智能} ');
    });

    test('addTag 在 selection 超出文本长度时截断到末尾', () {
      final controller = InlineTagController(text: '我想要');
      controller.value = const TextEditingValue(
        text: '我想要',
        selection: TextSelection.collapsed(offset: 100),
      );
      controller.addTag('人工智能');

      expect(controller.text, '我想要{人工智能} ');
    });

    test('plainText 把多个标签解码为空格分隔文本', () {
      final controller = InlineTagController(text: '我想要{人工智能}{北京}导师');

      expect(controller.plainText.trim(), '我想要 人工智能 北京 导师');
    });

    test('buildTextSpan 隐藏标签边界字符', () {
      final controller = InlineTagController(text: '我想要{人工智能}导师');
      final span = controller.buildTextSpan(
        context: MockBuildContext(),
        withComposing: false,
      );

      expect(span.children, isNotNull);
      expect(span.children!.length, greaterThan(1));
    });
  });
}

class MockBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
