class CompetitionCategoryNormalizer {
  const CompetitionCategoryNormalizer._();
  static const _aliases = {
    '电子信息类': '电子与信息类',
    '创新创业类': '综合与创业类',
    '综合创业类': '综合与创业类',
  };
  static String normalize(String category) =>
      _aliases[category.trim()] ?? category.trim();
}
