// test/features/competition_recommendation/widgets/competition_query_understanding_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/competition_query_understanding.dart';
import 'package:scho_navi/features/competition_recommendation/widgets/competition_query_understanding_card.dart';

void main() {
  testWidgets('渲染 AI 标题 + 键值行 + 待确认', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompetitionQueryUnderstandingCard(
            understanding: CompetitionQueryUnderstanding(
              directions: ['算法'],
              categories: ['计算机类'],
              timingPreferences: ['近期'],
              teamPreferences: ['个人'],
              uncertainties: ['是否需要组队'],
            ),
          ),
        ),
      ),
    );

    expect(find.text('我理解到的需求'), findsOneWidget);
    expect(find.text('算法'), findsOneWidget);
    expect(find.text('计算机类'), findsOneWidget);
    expect(find.text('待确认：'), findsOneWidget);
    expect(find.text('· 是否需要组队'), findsOneWidget);
  });
}
