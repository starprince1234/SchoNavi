import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/shared/widgets/empty_view.dart';
import 'package:scho_navi/shared/widgets/error_view.dart';
import 'package:scho_navi/shared/widgets/loading_view.dart';
import 'package:scho_navi/shared/widgets/match_level_chip.dart';
import 'package:scho_navi/shared/widgets/professor_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('LoadingView shows a progress indicator', (tester) async {
    await tester.pumpWidget(_wrap(const LoadingView()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ErrorView shows message and retry calls back', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(ErrorView(message: '服务异常', onRetry: () => tapped = true)),
    );
    expect(find.text('服务异常'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(tapped, isTrue);
  });

  testWidgets('EmptyView shows hint and edit action', (tester) async {
    var edited = false;
    await tester.pumpWidget(
      _wrap(
        EmptyView(
          message: '暂未找到完全符合条件的导师',
          actionLabel: '修改条件',
          onAction: () => edited = true,
        ),
      ),
    );
    expect(find.textContaining('暂未找到'), findsOneWidget);
    await tester.tap(find.text('修改条件'));
    expect(edited, isTrue);
  });

  testWidgets('MatchLevelChip renders the level label', (tester) async {
    await tester.pumpWidget(
      _wrap(const MatchLevelChip(level: MatchLevel.high)),
    );
    expect(find.textContaining('高'), findsOneWidget);
  });

  testWidgets('ProfessorCard shows name/university and triggers onTap', (
    tester,
  ) async {
    var tapped = false;
    const rec = Recommendation(
      professorId: 'p_001',
      name: '张三',
      university: '上海交通大学',
      college: '电子信息与电气工程学院',
      title: '教授',
      researchFields: ['医学影像', '计算机视觉'],
      matchLevel: MatchLevel.high,
      reason: '方向相关。',
      limitations: [],
    );
    await tester.pumpWidget(
      _wrap(ProfessorCard(recommendation: rec, onTap: () => tapped = true)),
    );
    expect(find.text('张三'), findsOneWidget);
    expect(find.textContaining('上海交通大学'), findsOneWidget);
    await tester.tap(find.byType(ProfessorCard));
    expect(tapped, isTrue);
  });
}
