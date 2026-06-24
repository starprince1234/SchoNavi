import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/utils/recommendation_need_classifier.dart';

void main() {
  const classifier = ConservativeRecommendationNeedClassifier();

  test('明确要求重新筛选时产卡', () async {
    expect(await classifier.needRecommendations('只看上海的导师'), isTrue);
    expect(await classifier.needRecommendations('再推荐几位相似的导师'), isTrue);
    expect(await classifier.needRecommendations('换一批'), isTrue);
  });

  test('针对已有导师的解释性问题不产卡', () async {
    expect(await classifier.needRecommendations('第一位导师在北京吗？'), isFalse);
    expect(await classifier.needRecommendations('他的研究方向是什么？'), isFalse);
    expect(await classifier.needRecommendations('为什么推荐他？'), isFalse);
  });
}
