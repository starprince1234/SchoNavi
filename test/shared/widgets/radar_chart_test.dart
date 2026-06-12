import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/shared/widgets/radar_chart.dart';

const _dims = [
  MatchDimension(label: '方向契合', score: 90, comment: 'a'),
  MatchDimension(label: '方法匹配', score: 78, comment: 'b'),
  MatchDimension(label: '地域', score: 95, comment: 'c'),
  MatchDimension(label: '学历目标', score: 70, comment: 'd'),
  MatchDimension(label: '产出活跃', score: 82, comment: 'e'),
];

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('渲染全部轴标签', (tester) async {
    await tester.pumpWidget(_wrap(const RadarChart(dimensions: _dims)));
    await tester.pumpAndSettle();

    expect(find.text('方向契合'), findsOneWidget);
    expect(find.text('产出活跃'), findsOneWidget);
  });

  testWidgets('点轴标签触发 onAxisTap(index)', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      _wrap(RadarChart(dimensions: _dims, onAxisTap: (i) => tapped = i)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('地域'));

    expect(tapped, 2);
  });

  testWidgets('空维度渲染为空占位', (tester) async {
    await tester.pumpWidget(_wrap(const RadarChart(dimensions: [])));
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });
}
