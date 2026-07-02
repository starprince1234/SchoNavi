import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/favorite_item.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/repositories/favorite_repository.dart';
import 'package:scho_navi/features/chat/widgets/recommendation_carousel.dart';
import 'package:scho_navi/shared/widgets/swipe_recommendation_card.dart';

Recommendation _rec(String id, String name) => Recommendation(
  professorId: id,
  name: name,
  university: '清华大学',
  college: '计算机学院',
  title: '教授',
  researchFields: ['计算机视觉'],
  matchLevel: MatchLevel.high,
  reason: '方向契合。',
  limitations: [],
);

/// 内存假收藏仓储，避免 sharedPrefs 依赖。
class _FakeFavoriteRepo implements FavoriteRepository {
  final _items = <String, FavoriteItem>{};
  final _controller = StreamController<List<FavoriteItem>>.broadcast();

  @override
  List<FavoriteItem> list() => _items.values.toList();
  @override
  Stream<List<FavoriteItem>> watch() => _controller.stream;
  @override
  bool isFavorite(String professorId) => _items.containsKey(professorId);
  @override
  Future<void> add(FavoriteItem item) async {
    _items[item.professorId] = item;
    _controller.add(list());
  }

  @override
  Future<void> remove(String professorId) async {
    _items.remove(professorId);
    _controller.add(list());
  }

  @override
  Future<bool> toggle(FavoriteItem item) async {
    if (_items.containsKey(item.professorId)) {
      await remove(item.professorId);
      return false;
    }
    await add(item);
    return true;
  }
}

Widget _wrap(Widget child) => ProviderScope(
  overrides: [
    favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
  ],
  child: MaterialApp(
    home: Scaffold(body: SizedBox(width: 360, height: 320, child: child)),
  ),
);

void main() {
  testWidgets('空列表不渲染轨道', (tester) async {
    await tester.pumpWidget(
      _wrap(RecommendationCarousel(recommendations: const [], onTap: (_) {})),
    );

    expect(find.byType(RecommendationCarousel), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('多张卡片渲染 PageView，indicator 数量匹配', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RecommendationCarousel(
          recommendations: [
            _rec('p_1', '张三'),
            _rec('p_2', '李四'),
            _rec('p_3', '王五'),
          ],
          onTap: (_) {},
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    // 3 个 indicator 圆点（用 Container 圆点近似定位：通过 Semantics label 更稳）。
    expect(find.byKey(const Key('carousel-indicator-0')), findsOneWidget);
    expect(find.byKey(const Key('carousel-indicator-1')), findsOneWidget);
    expect(find.byKey(const Key('carousel-indicator-2')), findsOneWidget);
  });

  testWidgets('单张卡片不显示 indicator', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RecommendationCarousel(
          recommendations: [_rec('p_1', '张三')],
          onTap: (_) {},
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byKey(const Key('carousel-indicator-0')), findsNothing);
  });

  testWidgets('点击卡片触发 onTap(id)', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      _wrap(
        RecommendationCarousel(
          recommendations: [_rec('p_1', '张三')],
          onTap: (id) => tapped = id,
        ),
      ),
    );

    await tester.tap(find.text('张三'));
    expect(tapped, 'p_1');
  });

  testWidgets('滑到第二张后父组件重建仍保持当前页', (tester) async {
    late StateSetter rebuild;
    var revision = 0;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return RecommendationCarousel(
              key: const ValueKey('stable-carousel'),
              recommendations: [
                _rec('p_1', '张三'),
                _rec('p_2', '李四'),
                _rec('p_3', '王五'),
              ],
              onTap: (_) {},
            );
          },
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('carousel-indicator-1'))).width,
      greaterThan(
        tester.getSize(find.byKey(const Key('carousel-indicator-0'))).width,
      ),
    );

    rebuild(() => revision++);
    expect(revision, 1);
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('carousel-indicator-1'))).width,
      greaterThan(
        tester.getSize(find.byKey(const Key('carousel-indicator-0'))).width,
      ),
    );
  });

  testWidgets('推荐数量缩减时页码安全回退且无异常', (tester) async {
    late StateSetter rebuild;
    var recommendations = [
      _rec('p_1', '张三'),
      _rec('p_2', '李四'),
      _rec('p_3', '王五'),
    ];
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return RecommendationCarousel(
              recommendations: recommendations,
              onTap: (_) {},
            );
          },
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();

    rebuild(() => recommendations = [_rec('p_1', '张三')]);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('carousel-indicator-0')), findsNothing);
    expect(find.text('张三'), findsOneWidget);
  });

  testWidgets('卡片提供当前序号与总数语义', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        RecommendationCarousel(
          recommendations: [_rec('p_1', '张三'), _rec('p_2', '李四')],
          onTap: (_) {},
        ),
      ),
    );

    expect(find.bySemanticsLabel(RegExp('第 1 张，共 2 张')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('长按卡片触发 onReportRecommendation 传入对应导师', (tester) async {
    Recommendation? reported;
    await tester.pumpWidget(
      _wrap(
        RecommendationCarousel(
          recommendations: [_rec('p_1', '张三')],
          onTap: (_) {},
          onReportRecommendation: (r) => reported = r,
        ),
      ),
    );
    await tester.longPress(find.byType(SwipeRecommendationCard));
    await tester.pump();
    expect(reported?.professorId, 'p_1');
  });
}
