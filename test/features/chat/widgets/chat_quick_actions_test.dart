import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/chat/widgets/chat_quick_actions.dart';
import 'package:scho_navi/shared/widgets/bento_tile.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('chip 保持纤细高度，不被 BentoTile 的 48px 触摸目标撑成圆胖', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: ChatQuickActions(
            actions: const ['换一批'],
            enabled: true,
            onTap: (action) => tapped = action,
          ),
        ),
      ),
    );

    // BentoTile 在 onTap != null 时曾用 ConstrainedBox(minHeight: 48) 撑高 chip，
    // 配合 borderRadius:20 渲染成又圆又胖的 stadium。修复后 chip 应回到内在高度。
    final chipHeight = tester.getSize(find.byType(BentoTile).first).height;
    expect(chipHeight, lessThan(48),
        reason: 'chip 不应被 BentoTile 的 minHeight:48 撑高成圆胖');
    expect(chipHeight, greaterThan(0));

    // 触摸目标放宽后，点击仍要可用。
    await tester.tap(find.text('换一批'));
    expect(tapped, '换一批');
  });

  testWidgets('actions 为空且不传 fallback 时隐藏 chip（不渲染兜底常量）',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: ChatQuickActions(
            actions: const [],
            enabled: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    // fallback 默认中和为空 → 空 actions → SizedBox.shrink，不渲染任何 chip。
    expect(find.byType(BentoTile), findsNothing);
    expect(find.text('换一批'), findsNothing);
    expect(find.text('适合硕士'), findsNothing);
  });

  testWidgets('显式传 fallback=defaultChatQuickActions 时仍显示兜底', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: ChatQuickActions(
            actions: const [],
            fallback: defaultChatQuickActions,
            enabled: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    // fallback 参数本身行为不变，调用方显式传入时仍兜底。
    expect(find.text('换一批'), findsOneWidget);
  });
}
