import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/shared/widgets/swipe_recommendation_card.dart';

const _rec = Recommendation(
  professorId: 'p_001',
  name: '张三',
  university: '清华大学',
  college: '计算机学院',
  title: '教授',
  researchFields: ['计算机视觉', '医学影像'],
  matchLevel: MatchLevel.high,
  reason: '方向高度契合，且在同城。',
  limitations: [],
  homepageUrl: 'https://example.edu',
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 320, child: child)),
);

void main() {
  testWidgets('渲染姓名/学校/职称与匹配度文案', (tester) async {
    await tester.pumpWidget(
      _wrap(SwipeRecommendationCard(recommendation: _rec, onTap: () {})),
    );

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('教授'), findsOneWidget);
    expect(find.textContaining('清华大学'), findsOneWidget);
    expect(find.textContaining('匹配度'), findsOneWidget);
  });

  testWidgets('点击卡片触发 onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        SwipeRecommendationCard(
          recommendation: _rec,
          onTap: () => tapped = true,
        ),
      ),
    );

    // 点姓名区域（卡片主体）。
    await tester.tap(find.text('张三'));
    expect(tapped, isTrue);
  });

  testWidgets('点击收藏按钮触发 onFavoritePressed，不冒泡到 onTap', (tester) async {
    var cardTapped = false;
    var favoriteTapped = false;
    await tester.pumpWidget(
      _wrap(
        SwipeRecommendationCard(
          recommendation: _rec,
          isFavorite: false,
          onTap: () => cardTapped = true,
          onFavoritePressed: () => favoriteTapped = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('收藏导师'));
    await tester.pump();

    expect(favoriteTapped, isTrue);
    expect(cardTapped, isFalse);
  });

  testWidgets('已收藏时按钮 tooltip 变为取消收藏', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SwipeRecommendationCard(
          recommendation: _rec,
          isFavorite: true,
          onTap: () {},
          onFavoritePressed: () {},
        ),
      ),
    );

    expect(find.byTooltip('取消收藏'), findsOneWidget);
  });

  testWidgets('提供主页回调时显示访问主页按钮', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SwipeRecommendationCard(
          recommendation: _rec,
          onTap: () {},
          onOpenHomepagePressed: () {},
        ),
      ),
    );

    expect(find.text('访问主页'), findsOneWidget);
  });

  testWidgets('320 宽度和 2 倍字体下长内容不溢出', (tester) async {
    const longRecommendation = Recommendation(
      professorId: 'p_long',
      name: '一位姓名非常长的导师用于布局验证',
      university: '一所名称非常非常长的高等院校',
      college: '一个名称同样非常长的学院与研究中心',
      title: '特聘教授及博士生导师',
      researchFields: ['超长研究方向名称一', '超长研究方向名称二', '超长研究方向名称三'],
      matchLevel: MatchLevel.high,
      reason: '这是一段很长的推荐理由，用于验证在窄屏幕和放大字体环境下仍然不会产生布局溢出。',
      limitations: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: SwipeRecommendationCard(
                recommendation: longRecommendation,
                onTap: () {},
                onFavoritePressed: () {},
                onOpenHomepagePressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('+1'), findsOneWidget);
  });
}
