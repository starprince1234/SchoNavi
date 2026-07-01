import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/inline_tag_input.dart';

const _placeholder = '\uFFFC';
const _chipKey = ValueKey('inline-tag-chip');

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('InlineTagController', () {
    test('addTag 在空文本末尾插入标签', () {
      final controller = InlineTagController();
      controller.addTag('人工智能');

      expect(controller.text, '$_placeholder ');
      expect(controller.selection.baseOffset, controller.text.length);
      expect(controller.plainText.trim(), '人工智能');
    });

    test('addTag 在光标位置插入标签', () {
      final controller = InlineTagController(text: '我想要导师');
      controller.selection = const TextSelection.collapsed(offset: 3);
      controller.addTag('人工智能');

      expect(controller.text, '我想要$_placeholder 导师');
      expect(controller.selection.baseOffset, 5);
      expect(controller.plainText.trim(), '我想要 人工智能 导师');
    });

    test('addTag 在无效 selection 时不崩溃，默认插到末尾', () {
      final controller = InlineTagController(text: '我想要');
      controller.selection = const TextSelection.collapsed(offset: -1);
      controller.addTag('人工智能');

      expect(controller.text, '我想要$_placeholder ');
      expect(controller.plainText.trim(), '我想要 人工智能');
    });

    test('addTag 在 selection 超出文本长度时截断到末尾', () {
      final controller = InlineTagController(text: '我想要');
      controller.value = const TextEditingValue(
        text: '我想要',
        selection: TextSelection.collapsed(offset: 100),
      );
      controller.addTag('人工智能');

      expect(controller.text, '我想要$_placeholder ');
      expect(controller.selection.baseOffset, controller.text.length);
    });

    test('旧格式标签会被解析为占位符并保留 plainText 顺序', () {
      final controller = InlineTagController(text: '我想要{人工智能}{北京}导师');

      expect(controller.text, '我想要$_placeholder$_placeholder导师');
      expect(controller.plainText.trim(), '我想要 人工智能 北京 导师');
    });

    test('buildTextSpan 使用 WidgetSpan 渲染标签', () {
      final controller = InlineTagController(text: '我想要{人工智能}导师');
      final span = controller.buildTextSpan(
        context: MockBuildContext(),
        withComposing: false,
      );

      expect(span.children, isNotNull);
      expect(span.children!.whereType<WidgetSpan>(), hasLength(1));
    });

    test('将 controller 赋值为普通文本时会清理旧标签元数据', () {
      final controller = InlineTagController();
      controller.addTag('人工智能');

      controller.value = const TextEditingValue(
        text: '普通文本',
        selection: TextSelection.collapsed(offset: 4),
      );

      expect(controller.text, '普通文本');
      expect(controller.plainText, '普通文本');

      final span = controller.buildTextSpan(
        context: MockBuildContext(),
        withComposing: false,
      );
      expect(span.children!.whereType<WidgetSpan>(), isEmpty);
    });
  });

  group('InlineTagInput widget', () {
    testWidgets('旧格式连续标签会渲染为可删除 inline chip', (tester) async {
      final controller = InlineTagController(text: '{人工智能}{北京} ');

      await tester.pumpWidget(_wrap(InlineTagInput(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byKey(_chipKey), findsNWidgets(2));
      expect(find.byIcon(Icons.close), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.close).at(0));
      await tester.pumpAndSettle();

      expect(controller.text, '$_placeholder ');
      expect(controller.plainText.trim(), '北京');
      expect(find.byKey(_chipKey), findsOneWidget);
    });

    testWidgets('短标签按内容宽度显示，不接近旧的最大宽度', (tester) async {
      final controller = InlineTagController(text: '{人工智能}{网络安全} ');

      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 320,
              child: InlineTagInput(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chips = find.byKey(_chipKey);
      expect(chips, findsNWidgets(2));

      final firstRect = tester.getRect(chips.at(0));
      final secondRect = tester.getRect(chips.at(1));

      expect(firstRect.width, lessThan(96));
      expect(secondRect.width, lessThan(96));
      expect(firstRect.width, lessThan(120));
      expect(secondRect.width, lessThan(120));
    });

    testWidgets('典型移动输入宽度下两个短标签保持同一行', (tester) async {
      final controller = InlineTagController(text: '{人工智能}{网络安全} ');

      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 260,
              child: InlineTagInput(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chips = find.byKey(_chipKey);
      expect(chips, findsNWidgets(2));

      final firstRect = tester.getRect(chips.at(0));
      final secondRect = tester.getRect(chips.at(1));

      expect((firstRect.center.dy - secondRect.center.dy).abs(), lessThan(2));
      expect(firstRect.right, lessThanOrEqualTo(secondRect.left));
    });

    testWidgets('窄宽度换行时 chip 不重叠且不越出输入框', (tester) async {
      final controller = InlineTagController(text: '{人工智能}{网络安全}{计算机科学}导师');

      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 150,
              child: InlineTagInput(controller: controller, maxLines: 5),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chips = find.byKey(_chipKey);
      expect(chips, findsNWidgets(3));

      final inputRect = tester.getRect(find.byType(InlineTagInput));
      final chipRects = List<Rect>.generate(
        3,
        (index) => tester.getRect(chips.at(index)),
      );

      for (final rect in chipRects) {
        expect(rect.left, greaterThanOrEqualTo(inputRect.left));
        expect(rect.right, lessThanOrEqualTo(inputRect.right));
      }

      for (var i = 0; i < chipRects.length; i++) {
        for (var j = i + 1; j < chipRects.length; j++) {
          expect(chipRects[i].overlaps(chipRects[j]), isFalse);
        }
      }
    });

    testWidgets('点击换行后的关闭按钮只删除对应标签', (tester) async {
      final controller = InlineTagController(text: '{人工智能}{网络安全}{计算机科学}导师');

      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 150,
              child: InlineTagInput(controller: controller, maxLines: 5),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).at(1));
      await tester.pumpAndSettle();

      expect(controller.plainText, '人工智能 计算机科学 导师');
      expect(find.byKey(_chipKey), findsNWidgets(2));
      expect(find.text('网络安全'), findsNothing);
    });
  });
}

class MockBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
